require 'cloud_controller/app_observer'
require 'cloud_controller/database_uri_generator'
require 'cloud_controller/undo_app_changes'
require 'cloud_controller/errors/application_missing'
require 'cloud_controller/errors/invalid_route_relation'
require 'repositories/runtime/app_usage_event_repository'
require 'actions/services/service_binding_delete'
require 'presenters/message_bus/service_binding_presenter'
require 'presenters/v3/cache_key_presenter'

require_relative 'buildpack'

module VCAP::CloudController
  # rubocop:disable ClassLength
  class App < Sequel::Model
    plugin :serialization
    plugin :after_initialize

    extend IntegerArraySerializer

    def after_initialize
      default_instances = db_schema[:instances][:default].to_i

      self.instances ||=  default_instances
      self.memory ||= VCAP::CloudController::Config.config[:default_app_memory]
    end

    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    one_to_many :droplets
    one_to_many :service_bindings
    one_to_many :events, class: VCAP::CloudController::AppEvent
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :admin_buildpack, class: VCAP::CloudController::Buildpack
    many_to_one :space, after_set: :validate_space
    many_to_one :stack
    many_to_many :routes, before_add: :validate_route, after_add: :handle_add_route, after_remove: :handle_remove_route
    one_through_one :organization, join_table: :spaces, left_key: :id, left_primary_key: :space_id, right_key: :organization_id

    one_to_one :current_saved_droplet,
               class: '::VCAP::CloudController::Droplet',
               key: :droplet_hash,
               primary_key: :droplet_hash

    add_association_dependencies routes: :nullify, events: :delete, droplets: :destroy

    export_attributes :name, :production, :space_guid, :stack_guid, :buildpack,
                      :detected_buildpack, :environment_json, :memory, :instances, :disk_quota,
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

    strip_attributes :name

    serialize_attributes :json, :metadata
    serialize_attributes :integer_array, :ports

    encrypt :environment_json, salt: :salt, column: :encrypted_environment_json
    encrypt :docker_credentials_json, salt: :docker_salt, column: :encrypted_docker_credentials_json

    APP_STATES = %w(STOPPED STARTED).map(&:freeze).freeze
    PACKAGE_STATES = %w(PENDING STAGED FAILED).map(&:freeze).freeze
    STAGING_FAILED_REASONS = %w(StagingError StagingTimeExpired NoAppDetectedError BuildpackCompileFailed
                                BuildpackReleaseFailed InsufficientResources NoCompatibleCell).map(&:freeze).freeze
    HEALTH_CHECK_TYPES = %w(port none).map(&:freeze).freeze

    # marked as true on changing the associated routes, and reset by
    # +Dea::Client.start+
    attr_accessor :routes_changed

    # Last staging response which will contain streaming log url
    attr_accessor :last_stager_response

    alias_method :diego?, :diego

    def copy_buildpack_errors
      bp = buildpack
      return if bp.valid?

      bp.errors.each do |err|
        errors.add(:buildpack, err)
      end
    end

    def validation_policies
      [
        AppEnvironmentPolicy.new(self),
        MaxDiskQuotaPolicy.new(self, max_app_disk_in_mb),
        MinDiskQuotaPolicy.new(self),
        MetadataPolicy.new(self, metadata_deserialized),
        MinMemoryPolicy.new(self),
        MaxMemoryPolicy.new(self, space, :space_quota_exceeded),
        MaxMemoryPolicy.new(self, organization, :quota_exceeded),
        MaxInstanceMemoryPolicy.new(self, organization && organization.quota_definition, :instance_memory_limit_exceeded),
        MaxInstanceMemoryPolicy.new(self, space && space.space_quota_definition, :space_instance_memory_limit_exceeded),
        InstancesPolicy.new(self),
        MaxAppInstancesPolicy.new(self, organization, organization && organization.quota_definition, :app_instance_limit_exceeded),
        MaxAppInstancesPolicy.new(self, space, space && space.space_quota_definition, :space_app_instance_limit_exceeded),
        HealthCheckPolicy.new(self, health_check_timeout),
        CustomBuildpackPolicy.new(self, custom_buildpacks_enabled?),
        DockerPolicy.new(self),
        PortsPolicy.new(self)
      ]
    end

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique [:space_id, :name]
      validates_format APP_NAME_REGEX, :name

      copy_buildpack_errors

      validates_includes PACKAGE_STATES, :package_state, allow_missing: true
      validates_includes APP_STATES, :state, allow_missing: true, message: 'must be one of ' + APP_STATES.join(', ')
      validates_includes STAGING_FAILED_REASONS, :staging_failed_reason, allow_nil: true
      validates_includes HEALTH_CHECK_TYPES, :health_check_type, allow_missing: true, message: 'must be one of ' + HEALTH_CHECK_TYPES.join(', ')

      validation_policies.map(&:validate)
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

    def before_save
      if needs_package_in_current_state? && !package_hash
        raise VCAP::Errors::ApiError.new_from_details('AppPackageInvalid', 'bits have not been uploaded')
      end

      self.stack ||= Stack.default
      self.memory ||= Config.config[:default_app_memory]
      self.disk_quota ||= Config.config[:default_app_disk_in_mb]
      self.enable_ssh = Config.config[:allow_app_ssh_access] && space.allow_ssh if enable_ssh.nil?

      if Config.config[:instance_file_descriptor_limit]
        self.file_descriptors ||= Config.config[:instance_file_descriptor_limit]
      end

      set_new_version if version_needs_to_be_updated?

      if diego.nil?
        self.diego = Config.config[:default_to_diego_backend]
      end

      super
    end

    def version_needs_to_be_updated?
      # change version if:
      #
      # * transitioning to STARTED
      # * memory is changed
      # * health check type is changed
      # * enable_ssh is changed
      #
      # this is to indicate that the running state of an application has changed,
      # and that the system should converge on this new version.
      (column_changed?(:state) ||
       column_changed?(:memory) ||
       column_changed?(:health_check_type) ||
       column_changed?(:enable_ssh)) && started?
    end

    def set_new_version
      self.version = SecureRandom.uuid
    end

    def update_detected_buildpack(detect_output, detected_buildpack_key)
      detected_admin_buildpack = Buildpack.find(key: detected_buildpack_key)
      if detected_admin_buildpack
        detected_buildpack_guid = detected_admin_buildpack.guid
        detected_buildpack_name = detected_admin_buildpack.name
      end

      update(
        detected_buildpack: detect_output,
        detected_buildpack_guid: detected_buildpack_guid,
        detected_buildpack_name: detected_buildpack_name || custom_buildpack_url
      )

      create_app_usage_buildpack_event
    end

    def needs_package_in_current_state?
      started?
      # started? && ((column_changed?(:state)) || (!new? && footprint_changed?))
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

    def buildpack_changed?
      column_changed?(:buildpack)
    end

    def desired_instances
      started? ? instances : 0
    end

    def organization
      space && space.organization
    end

    def before_destroy
      lock!
      self.state = 'STOPPED'

      destroy_service_bindings

      super
    end

    def destroy_service_bindings
      errors = ServiceBindingDelete.new.delete(self.service_bindings_dataset)
      raise errors.first unless errors.empty?
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
      (current_droplet && current_droplet.execution_metadata) || ''
    end

    def detected_start_command
      (current_droplet && current_droplet.detected_start_command) || ''
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

    def environment_json_with_serialization=(env)
      self.environment_json_without_serialization = MultiJson.dump(env)
    end
    alias_method_chain :environment_json=, 'serialization'

    def environment_json_with_serialization
      string = environment_json_without_serialization
      return if string.blank?
      MultiJson.load string
    end
    alias_method_chain :environment_json, 'serialization'

    def docker_credentials_json_with_serialization=(env)
      self.docker_credentials_json_without_serialization = MultiJson.dump(env)
    end
    alias_method_chain :docker_credentials_json=, 'serialization'

    def docker_credentials_json_with_serialization
      string = docker_credentials_json_without_serialization
      return if string.blank?
      MultiJson.load string
    end
    alias_method_chain :docker_credentials_json, 'serialization'

    def system_env_json
      vcap_services
    end

    def vcap_application
      app_name = app.nil? ? name : app.name
      {
        limits: {
          mem: memory,
          disk: disk_quota,
          fds: file_descriptors
        },
        application_id: guid,
        application_version: version,
        application_name: app_name,
        application_uris: uris,
        version: version,
        name: name,
        space_name: space.name,
        space_id: space_guid,
        uris: uris,
        users: nil
      }
    end

    def database_uri
      service_uris = service_bindings.map { |binding| binding.credentials['uri'] }.compact
      DatabaseUriGenerator.new(service_uris).database_uri
    end

    def validate_space(space)
      objection = Errors::InvalidRouteRelation.new(space.guid)

      raise objection unless routes.all? { |route| route.space_id == space.id }
      service_bindings.each { |binding| binding.validate_app_and_service_instance(self, binding.service_instance) }
    end

    def validate_route(route)
      objection = Errors::InvalidRouteRelation.new(route.guid)
      route_service_objection = Errors::InvalidRouteRelation.new("#{route.guid} - Route services are only supported for apps on Diego")

      raise objection if route.nil?
      raise objection if space.nil?
      raise objection if route.space_id != space.id
      raise route_service_objection if !route.route_service_url.nil? && !diego?

      raise objection unless route.domain.usable_by_organization?(space.organization)
    end

    def custom_buildpacks_enabled?
      !VCAP::CloudController::Config.config[:disable_custom_buildpacks]
    end

    def max_app_disk_in_mb
      VCAP::CloudController::Config.config[:maximum_app_disk_in_mb]
    end

    # We need to overide this ourselves because we are really doing a
    # many-to-many with ServiceInstances and want to remove the relationship
    # to that when we remove the binding like sequel would do if the
    # relationship was explicly defined as such.  However, since we need to
    # annotate the join table with binding specific info, we manage the
    # many_to_one and one_to_many sides of the relationship ourself.  If there
    # is a sequel option that I couldn't see that provides this behavior, this
    # method could be removed in the future.  Note, the sequel docs explicitly
    # state that the correct way to overide the remove_bla functionality is to
    # do so with the _ prefixed private method like we do here.
    def _remove_service_binding(binding)
      err = ServiceBindingDelete.new.delete([binding])
      raise(err[0]) if !err.empty?
    end

    def self.user_visibility_filter(user)
      {
        space_id: Space.dataset.join_table(:inner, :spaces_developers, space_id: :id, user_id: user.id).select(:spaces__id).union(
            Space.dataset.join_table(:inner, :spaces_managers, space_id: :id, user_id: user.id).select(:spaces__id)
          ).union(
              Space.dataset.join_table(:inner, :spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__id)
          ).union(
                Space.dataset.join_table(:inner, :organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__id)
          ).select(:id)
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

    def started?
      state == 'STARTED'
    end

    def active?
      if diego? && docker_image.present?
        return false unless FeatureFlag.enabled?('diego_docker')
      end
      true
    end

    def stopped?
      state == 'STOPPED'
    end

    def uris
      routes.map(&:uri)
    end

    def routing_info
      info = routes.map do |r|
        info = { 'hostname' => r.uri }
        info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
        info
      end
      { 'http_routes' => info }
    end

    def mark_as_staged
      self.package_state = 'STAGED'
      self.package_pending_since = nil
    end

    def mark_as_failed_to_stage(reason='StagingError')
      unless STAGING_FAILED_REASONS.include?(reason)
        logger.warn("Invalid staging failure reason: #{reason}, provided for app #{self.guid}")
        reason = 'StagingError'
      end

      self.package_state = 'FAILED'
      self.staging_failed_reason = reason
      self.staging_failed_description = VCAP::Errors::ApiError.new_from_details(reason, 'staging failed').message
      self.package_pending_since = nil
      self.state = 'STOPPED' if diego?
      save
    end

    def mark_for_restaging
      self.package_state = 'PENDING'
      self.staging_failed_reason = nil
      self.staging_failed_description = nil
      self.package_pending_since = Sequel::CURRENT_TIMESTAMP
    end

    def buildpack
      if admin_buildpack
        return admin_buildpack
      elsif super
        return CustomBuildpack.new(super)
      end

      AutoDetectionBuildpack.new
    end

    def buildpack=(buildpack_name)
      self.admin_buildpack = nil
      super(nil)
      admin_buildpack = Buildpack.find(name: buildpack_name.to_s)

      if admin_buildpack
        self.admin_buildpack = admin_buildpack
      elsif buildpack_name != '' # git url case
        super(buildpack_name)
      end
    end

    def buildpack_specified?
      !buildpack.is_a?(AutoDetectionBuildpack)
    end

    def custom_buildpack_url
      buildpack.url if buildpack.custom?
    end

    def buildpack_cache_key
      CacheKeyPresenter.cache_key(guid: guid, stack_name: stack.name)
    end

    def docker_image=(value)
      value = fill_docker_string(value)
      super
      self.package_hash = value
    end

    def package_hash=(hash)
      super(hash)
      mark_for_restaging if column_changed?(:package_hash)
      self.package_updated_at = Sequel.datetime_class.now
    end

    def stack=(stack)
      mark_for_restaging unless new?
      super(stack)
    end

    def add_new_droplet(hash)
      self.droplet_hash = hash
      add_droplet(droplet_hash: hash)
      save
    end

    def current_droplet
      return nil unless droplet_hash
      # The droplet may not be in the droplet table as we did not backfill
      # existing droplets when creating the table.
      current_saved_droplet || Droplet.create(app: self, droplet_hash: droplet_hash)
    end

    def start!
      self.state = 'STARTED'
      save
    end

    def stop!
      self.state = 'STOPPED'
      save
    end

    def restage!
      stop!
      mark_for_restaging
      start!
    end

    # returns True if we need to update the DEA's with
    # associated URL's.
    # We also assume that the relevant methods in +Dea::Client+ will reset
    # this app's routes_changed state
    # @return [Boolean, nil]
    def dea_update_pending?
      staged? && started? && @routes_changed
    end

    def after_commit
      super

      begin
        AppObserver.updated(self)
      rescue Errors::ApiError => e
        UndoAppChanges.new(self).undo(previous_changes) unless diego?
        raise e
      end
    end

    def to_hash(opts={})
      if VCAP::CloudController::SecurityContext.admin? || space.has_developer?(VCAP::CloudController::SecurityContext.current_user)
        opts.merge!(redact: %w(docker_credentials_json))
      else
        opts.merge!(redact: %w(environment_json system_env_json docker_credentials_json))
      end
      super(opts)
    end

    def is_v3?
      !is_v2?
    end

    def is_v2?
      app.nil?
    end

    def handle_add_route(route)
      mark_routes_changed(route)
      if is_v2?
        Repositories::Runtime::AppEventRepository.new.record_map_route(self, route, SecurityContext.current_user.try(:guid), SecurityContext.current_user_email)
      end
    end

    def handle_remove_route(route)
      mark_routes_changed(route)
      if is_v2?
        Repositories::Runtime::AppEventRepository.new.record_unmap_route(self, route, SecurityContext.current_user.try(:guid), SecurityContext.current_user_email)
      end
    end

    def handle_update_route(route)
      mark_routes_changed(route)
    end

    private

    def mark_routes_changed(_=nil)
      routes_already_changed = @routes_changed
      @routes_changed = true

      if diego?
        unless routes_already_changed
          App.db.after_commit do
            AppObserver.routes_changed(self)
            @routes_changed = false
          end
          self.updated_at = Sequel::CURRENT_TIMESTAMP
          save
        end
      else
        set_new_version
        save
      end
    end

    # there's no concrete schema for what constitutes a valid docker
    # repo/image reference online at the moment, so make a best effort to turn
    # the passed value into a complete, plausible docker image reference:
    # registry-name:registry-port/[scope-name/]repo-name:tag-name
    def fill_docker_string(value)
      segs = value.split('/')
      segs[-1] = segs.last + ':latest' unless segs.last.include?(':')
      segs.join('/')
    end

    def metadata_deserialized
      deserialized_values[:metadata]
    end

    WHITELIST_SERVICE_KEYS = %w(name label tags plan credentials syslog_drain_url).freeze

    def service_binding_json(binding)
      vcap_service = {}
      WHITELIST_SERVICE_KEYS.each do |key|
        vcap_service[key] = binding[key.to_sym] if binding[key.to_sym]
      end
      vcap_service
    end

    def vcap_services
      services_hash = {}
      service_bindings.each do |sb|
        binding = ServiceBindingPresenter.new(sb).to_hash
        service = service_binding_json(binding)
        services_hash[binding[:label]] ||= []
        services_hash[binding[:label]] << service
      end
      { 'VCAP_SERVICES' => services_hash }
    end

    def app_usage_event_repository
      @repository ||= Repositories::Runtime::AppUsageEventRepository.new
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
