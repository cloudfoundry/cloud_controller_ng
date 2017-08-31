require 'cloud_controller/app_observer'
require 'cloud_controller/database_uri_generator'
require 'cloud_controller/errors/application_missing'
require 'repositories/app_usage_event_repository'
require 'presenters/v3/cache_key_presenter'
require 'utils/uri_utils'
require 'models/runtime/helpers/package_state_calculator.rb'
require 'models/helpers/process_types'

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
      self.file_descriptors ||= Config.config.get(:instance_file_descriptor_limit) if Config.config.get(:instance_file_descriptor_limit)
    end

    NO_APP_PORT_SPECIFIED = -1
    DEFAULT_HTTP_PORT     = 8080
    DEFAULT_PORTS         = [DEFAULT_HTTP_PORT].freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :service_bindings, key: :app_guid, primary_key: :app_guid, without_guid_generation: true
    one_to_many :events, class: VCAP::CloudController::AppEvent, key: :app_id

    one_through_one :space,
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :guid, right_key: :space_guid

    one_through_one :stack,
      join_table:        BuildpackLifecycleDataModel.table_name,
      left_primary_key:  :app_guid, left_key: :app_guid,
      right_primary_key: :name, right_key: :stack,
      after_load:        :convert_nil_to_default_stack

    def convert_nil_to_default_stack(stack)
      self.associations[:stack] = Stack.default unless stack
    end

    one_through_one :latest_package,
      class:             'VCAP::CloudController::PackageModel',
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :app_guid, right_key: :guid,
      order:             [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_through_one :latest_droplet,
      class:             'VCAP::CloudController::DropletModel',
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :app_guid, right_key: :guid,
      order:             [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_through_one :latest_build,
      class:             'VCAP::CloudController::BuildModel',
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :app_guid, right_key: :guid,
      order:             [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    dataset_module do
      def staged
        association_join(:current_droplet)
      end

      def runnable
        staged.where("#{ProcessModel.table_name}__state".to_sym => STARTED).where { instances > 0 }
      end

      def diego
        where(diego: true)
      end

      def dea
        where(diego: false)
      end

      def buildpack_type
        inner_join(BuildpackLifecycleDataModel.table_name, app_guid: :app_guid)
      end
    end

    one_through_many :organization,
      [
        [ProcessModel.table_name, :id, :app_guid],
        [AppModel.table_name, :guid, :space_guid],
        [:spaces, :guid, :organization_id]
      ]

    many_to_many :routes,
      join_table: RouteMappingModel.table_name,
      left_primary_key: [:app_guid, :type], left_key: [:app_guid, :process_type],
      right_primary_key: :guid, right_key: :route_guid,
      distinct:     true,
      order:        Sequel.asc(:id)

    one_through_one :current_droplet,
      class:             '::VCAP::CloudController::DropletModel',
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :guid, right_key: :droplet_guid

    one_to_many :route_mappings, class: 'VCAP::CloudController::RouteMappingModel', primary_key: [:app_guid, :type], key: [:app_guid, :process_type]

    add_association_dependencies events: :delete

    export_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
                      :detected_buildpack, :detected_buildpack_guid, :environment_json, :memory, :instances, :disk_quota,
                      :state, :version, :command, :console, :debug, :staging_task_id,
                      :package_state, :health_check_type, :health_check_timeout, :health_check_http_endpoint,
                      :staging_failed_reason, :staging_failed_description, :diego, :docker_image, :package_updated_at,
                      :detected_start_command, :enable_ssh, :ports

    import_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
      :detected_buildpack, :environment_json, :memory, :instances, :disk_quota,
      :state, :command, :console, :debug, :staging_task_id,
      :service_binding_guids, :route_guids, :health_check_type, :health_check_http_endpoint,
      :health_check_timeout, :diego, :docker_image, :app_guid, :enable_ssh, :ports

    serialize_attributes :json, :metadata
    serialize_attributes :integer_array, :ports

    STARTED            = 'STARTED'.freeze
    STOPPED            = 'STOPPED'.freeze
    APP_STATES         = [STARTED, STOPPED].freeze
    HEALTH_CHECK_TYPES = %w(port none process http).map(&:freeze).freeze

    # Last staging response which will contain streaming log url
    attr_accessor :last_stager_response

    alias_method :diego?, :diego

    def dea?
      !diego?
    end

    # user_provided_ports method should be called to
    # get the value of ports stored in the database
    alias_method(:user_provided_ports, :ports)

    def package_hash
      return nil unless (cached_latest_package = latest_package)

      if cached_latest_package.bits?
        cached_latest_package.package_hash
      elsif cached_latest_package.docker?
        cached_latest_package.image
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
      current_droplet.try(:droplet_hash)
    end

    def droplet_checksum
      current_droplet.try(:checksum)
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

      app.lifecycle_data.errors.each do |_, errs|
        errs.each do |err|
          errors.add(:buildpack, err)
        end
      end
    end

    def validation_policies
      [
        MaxDiskQuotaPolicy.new(self, max_app_disk_in_mb),
        MinDiskQuotaPolicy.new(self),
        MetadataPolicy.new(self, metadata_deserialized),
        MinMemoryPolicy.new(self),
        AppMaxMemoryPolicy.new(self, space, :space_quota_exceeded),
        AppMaxMemoryPolicy.new(self, organization, :quota_exceeded),
        AppMaxInstanceMemoryPolicy.new(self, organization, :instance_memory_limit_exceeded),
        AppMaxInstanceMemoryPolicy.new(self, space, :space_instance_memory_limit_exceeded),
        InstancesPolicy.new(self),
        MaxAppInstancesPolicy.new(self, organization, organization && organization.quota_definition, :app_instance_limit_exceeded),
        MaxAppInstancesPolicy.new(self, space, space && space.space_quota_definition, :space_app_instance_limit_exceeded),
        HealthCheckPolicy.new(self, health_check_timeout),
        DockerPolicy.new(self),
        PortsPolicy.new(self, changed_from_dea_to_diego?),
        DiegoToDeaPolicy.new(self, changed_from_diego_to_dea?)
      ]
    end

    def validate
      validates_presence :app
      validate_uniqueness_of_type_for_same_app_model

      copy_buildpack_errors

      validates_includes APP_STATES, :state, allow_missing: true, message: 'must be one of ' + APP_STATES.join(', ')
      validates_includes HEALTH_CHECK_TYPES, :health_check_type, allow_missing: true, message: 'must be one of ' + HEALTH_CHECK_TYPES.join(', ')

      validate_health_check_type_and_port_presence_are_in_agreement
      validation_policies.map(&:validate)
      validate_health_check_http_endpoint
    end

    def validate_health_check_http_endpoint
      if health_check_type == 'http' && !UriUtils.is_uri_path?(health_check_http_endpoint)
        errors.add(:health_check_http_endpoint, "HTTP health check endpoint is not a valid URI path: #{health_check_http_endpoint}")
      end
    end

    def validate_uniqueness_of_type_for_same_app_model
      if non_unique_process_types.present? && new?
        non_unique_process_types_message = non_unique_process_types.push(type).sort.join(', ')
        errors.add(:type, Sequel.lit("application process types must be unique (case-insensitive), received: [#{non_unique_process_types_message}]"))
      end
    end

    def validate_health_check_type_and_port_presence_are_in_agreement
      default_to_port = nil
      if [default_to_port, 'port'].include?(health_check_type) && ports == []
        errors.add(:ports, 'ports array cannot be empty when health check type is "port"')
      end
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
      if diego.nil?
        self.diego = true
      end

      # column_changed?(:ports) reports false here for reasons unknown
      @ports_changed_by_user = changed_columns.include?(:ports)
      update_ports(nil) if changed_from_diego_to_dea? && !changed_columns.include?(:ports)
      super
    end

    def before_save
      set_new_version if version_needs_to_be_updated?
      super
    end

    def version_needs_to_be_updated?
      # change version if:
      #
      # * transitioning to STARTED
      # * memory is changed
      # * health check type is changed
      # * health check http endpoint is changed
      # * enable_ssh is changed
      # * ports were changed by the user
      #
      # this is to indicate that the running state of an application has changed,
      # and that the system should converge on this new version.

      (column_changed?(:state) ||
        column_changed?(:memory) ||
        column_changed?(:health_check_type) ||
        column_changed?(:health_check_http_endpoint) ||
        column_changed?(:enable_ssh) ||
        @ports_changed_by_user
      ) && started?
    end

    def enable_ssh
      app.enable_ssh
    end

    def set_new_version
      self.version = SecureRandom.uuid
    end

    def needs_package_in_current_state?
      started?
    end

    def in_suspended_org?
      space.in_suspended_org?
    end

    def being_started?
      column_changed?(:state) && started?
    end

    def being_stopped?
      column_changed?(:state) && stopped?
    end

    def scaling_operation?
      new? || !being_stopped?
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
      db.after_commit { AppObserver.deleted(self) }
    end

    def metadata_with_command
      result = metadata_without_command || self.metadata = {}
      command ? result.merge('command' => command) : result
    end

    alias_method_chain :metadata, :command

    def command_with_fallback
      cmd = command_without_fallback
      cmd = (cmd.nil? || cmd.empty?) ? nil : cmd
      cmd || metadata_without_command && metadata_without_command['command']
    end

    alias_method_chain :command, :fallback

    def execution_metadata
      current_droplet.try(:execution_metadata) || ''
    end

    def detected_start_command
      current_droplet.try(:process_types).try(:[], self.type) || ''
    end

    def detected_buildpack_guid
      current_droplet.try(:buildpack_receipt_buildpack_guid)
    end

    def detected_buildpack_name
      current_droplet.try(:buildpack_receipt_buildpack)
    end

    def detected_buildpack
      current_droplet.try(:buildpack_receipt_detect_output)
    end

    def staging_failed_reason
      latest_build.try(:error_id) || latest_droplet.try(:error_id)
    end

    def staging_failed_description
      latest_build.try(:error_description) || latest_droplet.try(:error_description)
    end

    def console=(c)
      self.metadata ||= {}
      self.metadata['console'] = c
    end

    def console
      # without the == true check, this expression can return nil if
      # the key doesn't exist, rather than false
      self.metadata && self.metadata['console'] == true
    end

    def debug=(d)
      self.metadata ||= {}
      # We don't support sending nil through API
      self.metadata['debug'] = (d == 'none') ? nil : d
    end

    def debug
      self.metadata && self.metadata['debug']
    end

    def name
      app.name
    end

    def environment_json
      app.environment_variables
    end

    def docker?
      app.docker?
    end

    def database_uri
      service_binding_uris = service_bindings.map do |binding|
        binding.credentials['uri'] if binding.credentials.present?
      end.compact
      DatabaseUriGenerator.new(service_binding_uris).database_uri
    end

    def custom_buildpacks_enabled?
      !VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
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
        "#{ProcessModel.table_name}__app_guid".to_sym => AppModel.where(space: space_guids.all).select(:guid)
      }
    end

    def needs_staging?
      package_hash && !staged? && started?
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
      current_droplet || latest_package.try(:ready?)
    end

    def active?
      if diego? && docker?
        return false unless FeatureFlag.enabled?(:diego_docker)
      end
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

      db.after_commit { AppObserver.updated(self) }
    end

    def to_hash(opts={})
      opts[:redact] = if !VCAP::CloudController::Security::AccessContext.new.can?(:read_env, self)
                        %w(environment_json system_env_json)
                      end
      super(opts)
    end

    def docker_ports
      exposed_ports = []
      if !self.needs_staging? && current_droplet.present? && self.execution_metadata.present?
        begin
          metadata = JSON.parse(self.execution_metadata)
          unless metadata['ports'].nil?
            metadata['ports'].each { |port|
              if port['Protocol'] == 'tcp'
                exposed_ports << port['Port']
              end
            }
          end
        rescue JSON::ParserError
        end
      end
      exposed_ports
    end

    def web?
      type == ProcessTypes::WEB
    end

    private

    def non_unique_process_types
      return [] unless app

      @non_unique_process_types ||= app.processes_dataset.select_map(:type).select do |process_type|
        process_type.downcase == type.downcase
      end
    end

    def changed_from_diego_to_dea?
      column_changed?(:diego) && initial_value(:diego).present? && !diego
    end

    def changed_from_dea_to_diego?
      column_changed?(:diego) && (initial_value(:diego) == false) && diego
    end

    def changed_from_default_ports?
      @ports_changed_by_user && (initial_value(:ports).nil? || initial_value(:ports) == [DEFAULT_HTTP_PORT])
    end

    # HACK: We manually call the Serializer here because the plugin uses the
    # _before_validation method to serialize ports. This is called before
    # validations and we want to set the default ports after validations.
    #
    # See:
    # https://github.com/jeremyevans/sequel/blob/7d6753da53196884e218a59a7dcd9a7803881b68/lib/sequel/model/base.rb#L1772-L1779
    def update_ports(new_ports)
      self.ports   = new_ports
      self[:ports] = IntegerArraySerializer.serializer.call(self.ports)
    end

    def metadata_deserialized
      deserialized_values[:metadata]
    end

    def app_usage_event_repository
      @repository ||= Repositories::AppUsageEventRepository.new
    end

    def create_app_usage_buildpack_event
      return unless staged? && started?
      app_usage_event_repository.create_from_process(self, 'BUILDPACK_SET')
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
      (column_changed?(:production) || column_changed?(:memory) ||
        column_changed?(:instances))
    end

    class << self
      def logger
        @logger ||= Steno.logger('cc.models.app')
      end
    end
  end

  App = ProcessModel
  # rubocop:enable ClassLength
end
