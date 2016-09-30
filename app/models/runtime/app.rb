require 'cloud_controller/app_observer'
require 'cloud_controller/database_uri_generator'
require 'cloud_controller/undo_app_changes'
require 'cloud_controller/errors/application_missing'
require 'repositories/app_usage_event_repository'
require 'presenters/v3/cache_key_presenter'

require_relative 'buildpack'

module VCAP::CloudController
  class App < Sequel::Model(:processes)
    include Serializer

    plugin :serialization
    plugin :after_initialize
    plugin :many_through_many

    extend IntegerArraySerializer

    def after_initialize
      self.instances        ||= db_schema[:instances][:default].to_i
      self.memory           ||= Config.config[:default_app_memory]
      self.disk_quota       ||= Config.config[:default_app_disk_in_mb]
      self.file_descriptors ||= Config.config[:instance_file_descriptor_limit] if Config.config[:instance_file_descriptor_limit]
    end

    DEFAULT_HTTP_PORT = 8080
    DEFAULT_PORTS     = [DEFAULT_HTTP_PORT].freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :service_bindings, key: :app_guid, primary_key: :app_guid, without_guid_generation: true
    one_to_many :events, class: VCAP::CloudController::AppEvent

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

    dataset_module do
      def staged
        association_join(:current_droplet)
      end

      def runnable
        staged.where("#{App.table_name}__state".to_sym => 'STARTED').where { instances > 0 }
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
        [App.table_name, :id, :app_guid],
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
                      :package_state, :health_check_type, :health_check_timeout,
                      :staging_failed_reason, :staging_failed_description, :diego, :docker_image, :package_updated_at,
                      :detected_start_command, :enable_ssh, :docker_credentials_json, :ports

    import_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
      :detected_buildpack, :environment_json, :memory, :instances, :disk_quota,
      :state, :command, :console, :debug, :staging_task_id,
      :service_binding_guids, :route_guids, :health_check_type,
      :health_check_timeout, :diego, :docker_image, :app_guid, :enable_ssh,
      :docker_credentials_json, :ports

    serialize_attributes :json, :metadata
    serialize_attributes :integer_array, :ports

    encrypt :docker_credentials_json, salt: :docker_salt, column: :encrypted_docker_credentials_json
    serializes_via_json :docker_credentials_json

    APP_STATES         = %w(STOPPED STARTED).map(&:freeze).freeze
    HEALTH_CHECK_TYPES = %w(port none process).map(&:freeze).freeze

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
      return nil unless latest_package

      if latest_package.bits?
        latest_package.package_hash
      elsif latest_package.docker?
        latest_package.image
      end
    end

    def package_state
      return 'FAILED' if latest_droplet.try(:failed?)
      return 'PENDING' if current_droplet != latest_droplet

      if current_droplet
        if latest_package
          return 'STAGED' if current_droplet.package == latest_package || current_droplet.created_at > latest_package.created_at
          return 'FAILED' if latest_package.failed?
          return 'PENDING'
        end

        return 'STAGED'
      end

      return 'FAILED' if latest_package.try(:failed?)

      'PENDING'
    end

    def staging_task_id
      latest_droplet.try(:guid)
    end

    def droplet_hash
      current_droplet.try(:droplet_hash)
    end

    def package_updated_at
      latest_package.try(:created_at)
    end

    def docker_image
      latest_package.try(:image)
    end

    def copy_buildpack_errors
      bp = buildpack
      return if bp.valid?

      bp.errors.each do |err|
        errors.add(:buildpack, err)
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
        self.diego = Config.config[:default_to_diego_backend]
      end

      # column_changed?(:ports) reports false here for reasons unknown
      @ports_changed_by_user = changed_columns.include?(:ports)
      update_ports(nil) if changed_from_diego_to_dea? && !changed_columns.include?(:ports)
      super
    end

    def before_save
      self.enable_ssh = Config.config[:allow_app_ssh_access] && space.allow_ssh if enable_ssh.nil?
      set_new_version if version_needs_to_be_updated?
      super
    end

    def version_needs_to_be_updated?
      # change version if:
      #
      # * transitioning to STARTED
      # * memory is changed
      # * health check type is changed
      # * enable_ssh is changed
      # * ports were changed by the user
      #
      # this is to indicate that the running state of an application has changed,
      # and that the system should converge on this new version.

      (column_changed?(:state) ||
        column_changed?(:memory) ||
        column_changed?(:health_check_type) ||
        column_changed?(:enable_ssh) ||
        @ports_changed_by_user
      ) && started?
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
    end

    def after_destroy_commit
      super
      AppObserver.deleted(self)
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
      latest_droplet.try(:error_id)
    end

    def staging_failed_description
      latest_droplet.try(:error_description)
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
      service_uris = service_bindings.map { |binding| binding.credentials['uri'] }.compact
      DatabaseUriGenerator.new(service_uris).database_uri
    end

    def validate_space(space)
      objection = CloudController::Errors::InvalidRouteRelation.new(space.guid)
      raise objection unless routes.all? { |route| route.space_id == space.id }

      service_bindings.each { |binding| binding.validate_app_and_service_instance(self, binding.service_instance) }

      raise CloudController::Errors::ApiError.new_from_details('SpaceInvalid', 'apps cannot be moved into different spaces') if column_changed?(:space_id) && !new?
    end

    def custom_buildpacks_enabled?
      !VCAP::CloudController::Config.config[:disable_custom_buildpacks]
    end

    def max_app_disk_in_mb
      VCAP::CloudController::Config.config[:maximum_app_disk_in_mb]
    end

    def self.user_visibility_filter(user)
      space_guids = Space.join(:spaces_developers, space_id: :id, user_id: user.id).select(:spaces__guid).
                    union(Space.join(:spaces_managers, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__guid)).select(:guid)

      {
        "#{App.table_name}__app_guid".to_sym => AppModel.where(space: space_guids.all).select(:guid)
      }
    end

    def needs_staging?
      package_hash && !staged? && started? && instances > 0
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
      pending? && !latest_droplet.nil? && latest_droplet.staging?
    end

    def started?
      state == 'STARTED'
    end

    def active?
      if diego? && docker?
        return false unless FeatureFlag.enabled?(:diego_docker)
      end
      true
    end

    def stopped?
      state == 'STOPPED'
    end

    def uris
      routes.map(&:uri)
    end

    def buildpack
      if app && app.lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
        return AutoDetectionBuildpack.new if app.lifecycle_data.buildpack.nil?

        known_buildpack = Buildpack.find(name: app.lifecycle_data.buildpack)
        return known_buildpack if known_buildpack

        return CustomBuildpack.new(app.lifecycle_data.buildpack)
      else
        AutoDetectionBuildpack.new
      end
    end

    def buildpack_specified?
      !buildpack.is_a?(AutoDetectionBuildpack)
    end

    def custom_buildpack_url
      buildpack.url if buildpack.custom?
    end

    def buildpack_cache_key
      Presenters::V3::CacheKeyPresenter.cache_key(guid: guid, stack_name: stack.name)
    end

    def after_commit
      super

      begin
        AppObserver.updated(self)
      rescue CloudController::Errors::ApiError => e
        UndoAppChanges.new(self).undo(previous_changes) unless diego?
        raise e
      end
    end

    def to_hash(opts={})
      admin_override = VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      opts[:redact] = if admin_override || space.has_developer?(VCAP::CloudController::SecurityContext.current_user)
                        %w(docker_credentials_json)
                      else
                        %w(environment_json system_env_json docker_credentials_json)
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
      app_usage_event_repository.create_from_app(self, 'BUILDPACK_SET')
    end

    def create_app_usage_event
      return unless app_usage_changed?
      app_usage_event_repository.create_from_app(self)
    end

    def app_usage_changed?
      previously_started = initial_value(:state) == 'STARTED'
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
  # rubocop:enable ClassLength
end

module VCAP::CloudController
  ProcessModel = App
end
