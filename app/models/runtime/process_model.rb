require 'cloud_controller/process_observer'
require 'cloud_controller/database_uri_generator'
require 'cloud_controller/errors/application_missing'
require 'repositories/app_usage_event_repository'
require 'presenters/v3/cache_key_presenter'
require 'utils/uri_utils'
require 'models/runtime/helpers/package_state_calculator'
require 'models/helpers/process_types'
require 'models/helpers/health_check_types'
require 'cloud_controller/serializer'
require 'cloud_controller/integer_array_serializer'

require_relative 'buildpack'

module VCAP::CloudController
  class ProcessModel < Sequel::Model(:processes)
    include Serializer

    plugin :serialization
    plugin :after_initialize
    plugin :many_through_many

    extend IntegerArraySerializer

    def after_initialize
      self.instances        ||= db_schema[:instances][:default].to_i
      self.memory           ||= Config.config.get(:default_app_memory)
      self.disk_quota       ||= Config.config.get(:default_app_disk_in_mb)
      self.file_descriptors ||= Config.config.get(:instance_file_descriptor_limit)
      self.log_rate_limit   ||= Config.config.get(:default_app_log_rate_limit_in_bytes_per_second)
      self.metadata         ||= {}
    end

    NO_APP_PORT_SPECIFIED = -1
    DEFAULT_HTTP_PORT     = 8080
    DEFAULT_PORTS         = [DEFAULT_HTTP_PORT].freeze
    UNLIMITED_LOG_RATE    = -1

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :revision, class: 'VCAP::CloudController::RevisionModel', key: :revision_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :service_bindings, key: :app_guid, primary_key: :app_guid, without_guid_generation: true
    one_to_many :events, class: VCAP::CloudController::AppEvent, key: :app_id

    one_to_many :labels, class: 'VCAP::CloudController::ProcessLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ProcessAnnotationModel', key: :resource_guid, primary_key: :guid

    one_through_one :space,
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :guid, right_key: :space_guid

    one_through_one :stack,
                    join_table: BuildpackLifecycleDataModel.table_name,
                    left_primary_key: :app_guid, left_key: :app_guid,
                    right_primary_key: :name, right_key: :stack,
                    after_load: :convert_nil_to_default_stack

    def convert_nil_to_default_stack(stack)
      associations[:stack] = Stack.default unless stack
    end

    one_through_one :latest_package,
                    class: 'VCAP::CloudController::PackageModel',
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :app_guid, right_key: :guid,
                    order: [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_through_one :latest_build,
                    class: 'VCAP::CloudController::BuildModel',
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :app_guid, right_key: :guid,
                    order: [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_through_one :latest_droplet,
                    class: 'VCAP::CloudController::DropletModel',
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :app_guid, right_key: :guid,
                    order: [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_through_one :desired_droplet,
                    class: '::VCAP::CloudController::DropletModel',
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :guid, right_key: :droplet_guid

    dataset_module do
      def staged
        association_join(:desired_droplet)
      end

      def runnable
        staged.where("#{ProcessModel.table_name}__state": STARTED).where { instances > 0 }
      end

      def diego
        where(diego: true)
      end

      def buildpack_type
        inner_join(BuildpackLifecycleDataModel.table_name, app_guid: :app_guid).
          select_all(:processes)
      end

      def non_docker_type
        inner_join(BuildpackLifecycleDataModel.table_name, app_guid: :app_guid).
          select_all(:processes)
      end
    end

    one_through_many :organization,
                     [
                       [ProcessModel.table_name, :id, :app_guid],
                       [AppModel.table_name, :guid, :space_guid],
                       %i[spaces guid organization_id]
                     ]

    many_to_many :routes,
                 join_table: RouteMappingModel.table_name,
                 left_primary_key: %i[app_guid type], left_key: %i[app_guid process_type],
                 right_primary_key: :guid, right_key: :route_guid,
                 distinct: true,
                 order: Sequel.asc(:id),
                 eager: :domain

    many_to_many :sidecars,
                 class: 'VCAP::CloudController::SidecarModel',
                 join_table: SidecarProcessTypeModel.table_name,
                 left_primary_key: %i[app_guid type], left_key: %i[app_guid type],
                 right_primary_key: :guid, right_key: :sidecar_guid,
                 distinct: true,
                 order: Sequel.asc(:id)

    one_to_many :route_mappings, class: 'VCAP::CloudController::RouteMappingModel', primary_key: %i[app_guid type], key: %i[app_guid process_type]

    add_association_dependencies events: :delete
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    export_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
                      :detected_buildpack, :detected_buildpack_guid, :environment_json,
                      :memory, :instances, :disk_quota, :log_rate_limit, :state, :version,
                      :command, :console, :debug, :staging_task_id, :package_state,
                      :health_check_type, :health_check_timeout, :health_check_http_endpoint,
                      :staging_failed_reason, :staging_failed_description, :diego,
                      :docker_image, :package_updated_at, :detected_start_command, :enable_ssh,
                      :ports

    import_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
                      :detected_buildpack, :environment_json, :memory, :instances, :disk_quota,
                      :log_rate_limit, :state, :command, :console, :debug, :staging_task_id,
                      :service_binding_guids, :route_guids, :health_check_type,
                      :health_check_http_endpoint, :health_check_timeout, :diego,
                      :docker_image, :app_guid, :enable_ssh, :ports

    serialize_attributes :json, :metadata
    serialize_attributes :integer_array, :ports

    STARTED            = 'STARTED'.freeze
    STOPPED            = 'STOPPED'.freeze
    APP_STATES         = [STARTED, STOPPED].freeze
    HEALTH_CHECK_TYPES = [
      HealthCheckTypes::PORT,
      HealthCheckTypes::PROCESS,
      HealthCheckTypes::HTTP,
      HealthCheckTypes::NONE
    ].freeze

    # Last staging response which will contain streaming log url
    attr_accessor :last_stager_response, :skip_process_observer_on_update, :skip_process_version_update

    alias_method :diego?, :diego

    def revisions_enabled?
      app.revisions_enabled
    end

    delegate :file_based_service_bindings_enabled, to: :app

    def package_hash
      # this caches latest_package for performance reasons
      package = latest_package
      return nil if package.nil?

      if package.bits?
        package.checksum_info[:value]
      elsif package.docker?
        package.image
      end
    end

    def package_state
      calculator = PackageStateCalculator.new(self)
      calculator.calculate
    end

    def staging_task_id
      latest_build.try(:guid) || latest_droplet.try(:guid)
    end

    def droplet_hash
      desired_droplet.try(:droplet_hash)
    end

    def droplet_checksum
      desired_droplet.try(:checksum)
    end

    def actual_droplet
      return desired_droplet unless revisions_enabled?

      revision&.droplet || desired_droplet
    end

    def environment_json
      return app.environment_variables unless revisions_enabled?

      revision&.environment_variables || app.environment_variables
    end

    def package_updated_at
      latest_package.try(:created_at)
    end

    def docker_image
      latest_package.try(:image)
    end

    def docker_username
      latest_package.try(:docker_username)
    end

    def docker_password
      latest_package.try(:docker_password)
    end

    def copy_buildpack_errors
      return unless app&.lifecycle_data
      return if app.lifecycle_data.valid?

      app.lifecycle_data.errors.each_value do |errs|
        errs.each do |err|
          errors.add(:buildpack, err)
        end
      end
    end

    def validation_policies
      [
        MaxDiskQuotaPolicy.new(self, max_app_disk_in_mb),
        MinDiskQuotaPolicy.new(self),
        MinMemoryPolicy.new(self),
        AppMaxMemoryPolicy.new(self, space, :space_quota_exceeded),
        AppMaxMemoryPolicy.new(self, organization, :quota_exceeded),
        AppMaxInstanceMemoryPolicy.new(self, organization, :instance_memory_limit_exceeded),
        AppMaxInstanceMemoryPolicy.new(self, space, :space_instance_memory_limit_exceeded),
        InstancesPolicy.new(self),
        MaxAppInstancesPolicy.new(self, organization, organization && organization.quota_definition, :app_instance_limit_exceeded),
        MaxAppInstancesPolicy.new(self, space, space && space.space_quota_definition, :space_app_instance_limit_exceeded),
        MinLogRateLimitPolicy.new(self),
        AppMaxLogRateLimitPolicy.new(self, space, 'exceeds space log rate quota'),
        AppMaxLogRateLimitPolicy.new(self, organization, 'exceeds organization log rate quota'),
        HealthCheckPolicy.new(self, health_check_timeout, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval),
        ReadinessHealthCheckPolicy.new(self, readiness_health_check_invocation_timeout, readiness_health_check_type, readiness_health_check_http_endpoint,
                                       readiness_health_check_interval),
        DockerPolicy.new(self),
        PortsPolicy.new(self)
      ]
    end

    def validate
      validates_presence :app

      copy_buildpack_errors

      validates_includes APP_STATES, :state, allow_missing: true, message: 'must be one of ' + APP_STATES.join(', ')

      validation_policies.map(&:validate)
      validate_sidecar_memory if modified?(:memory)
    end

    def validate_sidecar_memory
      return if SidecarMemoryLessThanProcessMemoryPolicy.new([self]).valid?

      errors.add(:memory, :process_memory_insufficient_for_sidecars)
    end

    def before_create
      set_new_version
      super
    end

    def after_create
      super
      create_app_usage_event
    end

    def after_update
      super
      create_app_usage_event
    end

    def before_validation
      # This is in before_validation because we need to validate ports based on diego flag
      self.diego = true if diego.nil?

      # column_changed?(:ports) reports false here for reasons unknown
      @ports_changed_by_user = changed_columns.include?(:ports)
      super
    end

    def before_save
      set_new_version if version_needs_to_be_updated?
      super
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def version_needs_to_be_updated?
      # change version if:
      #
      # * transitioning to STARTED
      # * memory is changed
      # * health check type is changed
      # * health check http endpoint is changed
      # * readiness health check type is changed
      # * readiness health check http endpoint is changed
      # * ports were changed by the user
      #
      # this is to indicate that the running state of an application has changed,
      # and that the system should converge on this new version.

      started? &&
        (column_changed?(:state) ||
        (column_changed?(:memory) && !skip_process_version_update) ||
        (column_changed?(:health_check_type) && !skip_process_version_update) ||
        (column_changed?(:readiness_health_check_type) && !skip_process_version_update) ||
        (column_changed?(:health_check_http_endpoint) && !skip_process_version_update) ||
        (column_changed?(:readiness_health_check_http_endpoint) && !skip_process_version_update) ||
        (@ports_changed_by_user && !skip_process_version_update)
        )
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    delegate :enable_ssh, to: :app

    def set_new_version
      self.version = SecureRandom.uuid
    end

    def needs_package_in_current_state?
      started?
    end

    delegate :in_suspended_org?, to: :space

    def being_started?
      column_changed?(:state) && started?
    end

    def being_stopped?
      column_changed?(:state) && stopped?
    end

    def desired_instances
      started? ? instances : 0
    end

    def before_destroy
      lock!
      self.state = 'STOPPED'
      super
    end

    def after_destroy
      super
      create_app_usage_event
      db.after_commit { ProcessObserver.deleted(self) }
    end

    def execution_metadata
      desired_droplet.try(:execution_metadata) || ''
    end

    def started_command
      return specified_or_detected_command if !revisions_enabled? || revision.nil?

      specified_commands = revision.commands_by_process_type
      specified_commands[type] || revision.droplet&.process_start_command(type) || ''
    end

    def specified_or_detected_command
      command.presence || detected_start_command
    end

    def detected_start_command
      desired_droplet&.process_start_command(type) || ''
    end

    def detected_buildpack_guid
      desired_droplet.try(:buildpack_receipt_buildpack_guid)
    end

    def detected_buildpack_name
      desired_droplet.try(:buildpack_receipt_buildpack)
    end

    def detected_buildpack
      desired_droplet.try(:buildpack_receipt_detect_output)
    end

    def staging_failed_reason
      latest_build.try(:error_id) || latest_droplet.try(:error_id)
    end

    def staging_failed_description
      latest_build.try(:error_description) || latest_droplet.try(:error_description)
    end

    def console=(value)
      self.metadata ||= {}
      self.metadata['console'] = value
    end

    def console
      # without the == true check, this expression can return nil if
      # the key doesn't exist, rather than false
      self.metadata && self.metadata['console'] == true
    end

    def debug=(value)
      self.metadata ||= {}
      # We don't support sending nil through API
      self.metadata['debug'] = value == 'none' ? nil : value
    end

    def debug
      self.metadata && self.metadata['debug']
    end

    delegate :name, to: :app

    delegate :docker?, to: :app

    delegate :cnb?, to: :app

    def database_uri
      service_binding_uris = service_bindings.map do |binding|
        binding.credentials['uri'] if binding.credentials.present?
      end.compact
      DatabaseUriGenerator.new(service_binding_uris).database_uri
    end

    def max_app_disk_in_mb
      VCAP::CloudController::Config.config.get(:maximum_app_disk_in_mb)
    end

    def self.user_visibility_filter(user)
      space_guids = Space.join(:spaces_developers, space_id: :id, user_id: user.id).select(:spaces__guid).
                    union(Space.join(:spaces_managers, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__guid)).select(:guid)

      {
        "#{ProcessModel.table_name}__app_guid": AppModel.where(space: space_guids.all).select(:guid)
      }
    end

    def needs_staging?
      package_hash.present? && !staged? && started?
    end

    def staged?
      package_state == 'STAGED'
    end

    def staging_failed?
      package_state == 'FAILED'
    end

    def pending?
      package_state == 'PENDING'
    end

    def staging?
      pending? && latest_build.present? && latest_build.staging?
    end

    def started?
      state == STARTED
    end

    def package_available?
      desired_droplet || latest_package.try(:ready?)
    end

    def active?
      return false if docker? && !FeatureFlag.enabled?(:diego_docker)
      return false if cnb? && !FeatureFlag.enabled?(:diego_cnb)

      true
    end

    def stopped?
      state == STOPPED
    end

    def uris
      routes.map(&:uri)
    end

    def buildpack
      app.lifecycle_data.buildpack_models.first
    end

    def buildpack_specified?
      app.lifecycle_data.buildpacks.any?
    end

    def custom_buildpack_url
      app.lifecycle_data.first_custom_buildpack_url
    end

    def after_save
      super

      db.after_commit { ProcessObserver.updated(self) unless skip_process_observer_on_update }
    end

    def to_hash(opts={})
      opts[:redact] = (%w[environment_json system_env_json] unless VCAP::CloudController::Security::AccessContext.new.can?(:read_env, self))
      super
    end

    def web?
      type == ProcessTypes::WEB
    end

    def docker_ports
      return desired_droplet.docker_ports if desired_droplet.present? && desired_droplet.staged?

      []
    end

    def open_ports
      open_ports = ports || []

      if docker?
        has_mapping_without_port = route_mappings_dataset.where(app_port: ProcessModel::NO_APP_PORT_SPECIFIED).any?
        needs_docker_ports = docker_ports.present? && (has_mapping_without_port || open_ports.empty?)

        open_ports += docker_ports if needs_docker_ports

        open_ports += DEFAULT_PORTS if docker_ports.blank? && has_mapping_without_port
      end

      open_ports += DEFAULT_PORTS if web? && open_ports.empty?
      open_ports.uniq
    end

    private

    def non_unique_process_types
      return [] unless app

      @non_unique_process_types ||= app.processes_dataset.select_map(:type).select do |process_type|
        process_type.downcase == type.downcase
      end
    end

    def changed_from_default_ports?
      @ports_changed_by_user && (initial_value(:ports).nil? || initial_value(:ports) == [DEFAULT_HTTP_PORT])
    end

    def metadata_deserialized
      deserialized_values[:metadata]
    end

    def app_usage_event_repository
      @app_usage_event_repository ||= Repositories::AppUsageEventRepository.new
    end

    def create_app_usage_event
      return unless app_usage_changed?

      app_usage_event_repository.create_from_process(self)
    end

    def app_usage_changed?
      previously_started = initial_value(:state) == STARTED
      return true if previously_started != started?
      return true if started? && footprint_changed?

      false
    end

    def footprint_changed?
      column_changed?(:production) || column_changed?(:memory) ||
        column_changed?(:instances)
    end

    class << self
      def logger
        @logger ||= Steno.logger('cc.models.app')
      end
    end
  end
end
