require "cloud_controller/app_observer"
require "cloud_controller/database_uri_generator"
require "cloud_controller/undo_app_changes"
require "cloud_controller/errors/application_missing"
require "cloud_controller/errors/invalid_route_relation"
require "repositories/runtime/app_usage_event_repository"

require_relative "buildpack"

module VCAP::CloudController
  # rubocop:disable ClassLength
  class App < Sequel::Model
    plugin :serialization

    APP_NAME_REGEX = /\A[[[:alnum:][:punct:][:print:]]&&[^;]]+\Z/.freeze

    one_to_many :droplets
    one_to_many :service_bindings
    one_to_many :events, :class => VCAP::CloudController::AppEvent
    many_to_one :admin_buildpack, class: VCAP::CloudController::Buildpack
    many_to_one :space
    many_to_one :stack
    many_to_many :routes, before_add: :validate_route, after_add: :mark_routes_changed, after_remove: :mark_routes_changed

    add_association_dependencies routes: :nullify, service_bindings: :destroy, events: :delete, droplets: :destroy

    default_order_by :name

    export_attributes :name, :production,
                      :space_guid, :stack_guid, :buildpack, :detected_buildpack,
                      :environment_json, :memory, :instances, :disk_quota,
                      :state, :version, :command, :console, :debug,
                      :staging_task_id, :package_state, :health_check_timeout,
                      :staging_failed_reason

    import_attributes :name, :production,
                      :space_guid, :stack_guid, :buildpack, :detected_buildpack,
                      :environment_json, :memory, :instances, :disk_quota,
                      :state, :command, :console, :debug,
                      :staging_task_id, :service_binding_guids, :route_guids, :health_check_timeout

    strip_attributes :name

    serialize_attributes :json, :metadata

    APP_STATES = %w[STOPPED STARTED].map(&:freeze).freeze
    PACKAGE_STATES = %w[PENDING STAGED FAILED].map(&:freeze).freeze
    STAGING_FAILED_REASONS = %w[StagingError NoAppDetectedError BuildpackCompileFailed BuildpackReleaseFailed].map(&:freeze).freeze

    CENSORED_FIELDS = [:encrypted_environment_json, :command, :environment_json]

    CENSORED_MESSAGE = "PRIVATE DATA HIDDEN".freeze

    def self.audit_hash(request_attrs)
      request_attrs.dup.tap do |changes|
        CENSORED_FIELDS.map(&:to_s).each do |censored|
          changes[censored] = CENSORED_MESSAGE if changes.has_key?(censored)
        end
      end
    end

    # marked as true on changing the associated routes, and reset by
    # +DeaClient.start+
    attr_accessor :routes_changed

    # Last staging response which will contain streaming log url
    attr_accessor :last_stager_response

    alias_method :kill_after_multiple_restarts?, :kill_after_multiple_restarts

    def copy_buildpack_errors
      bp = buildpack

      unless bp.valid?
        bp.errors.each do |err|
          errors.add(:buildpack, err)
        end
      end
    end

    def validation_policies
      [
          AppEnvironmentPolicy.new(self),
          DiskQuotaPolicy.new(self, max_app_disk_in_mb),
          MetadataPolicy.new(self, metadata_deserialized),
          MinMemoryPolicy.new(self),
          MaxMemoryPolicy.new(self),
          InstancesPolicy.new(self),
          HealthCheckPolicy.new(self, health_check_timeout),
          CustomBuildpackPolicy.new(self, custom_buildpacks_enabled?)
      ]
    end

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique [:space_id, :name]
      validates_format APP_NAME_REGEX, :name

      copy_buildpack_errors

      validates_includes PACKAGE_STATES, :package_state, :allow_missing => true
      validates_includes APP_STATES, :state, :allow_missing => true
      validates_includes STAGING_FAILED_REASONS, :staging_failed_reason, :allow_nil => true

      validation_policies.map(&:validate)
    end

    def before_create
      super
      set_new_version
    end

    def before_save
      if generate_start_event? && !package_hash
        raise VCAP::Errors::ApiError.new_from_details("AppPackageInvalid", "bits have not been uploaded")
      end

      super

      self.stack ||= Stack.default
      self.memory ||= Config.config[:default_app_memory]
      self.disk_quota ||= Config.config[:default_app_disk_in_mb]

      set_new_version if version_needs_to_be_updated?

      AppStopEvent.create_from_app(self) if generate_stop_event?
      AppStartEvent.create_from_app(self) if generate_start_event?
    end

    def after_save
      create_app_usage_event
      super
    end

    def version_needs_to_be_updated?
      # change version if:
      #
      # * transitioning to STARTED
      # * memory is changed
      # * routes are changed
      #
      # this is to indicate that the running state of an application has changed,
      # and that the system should converge on this new version.
      (column_changed?(:state) || column_changed?(:memory)) && started?
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

    def generate_start_event?
      # Change to app state is given priority over change to footprint as
      # we would like to generate only either start or stop event exactly
      # once during a state change. Also, if the app is not in started state
      # and/or is new, then the changes to the footprint shouldn't trigger a
      # billing event.
      started? && ((column_changed?(:state)) || (!new? && footprint_changed?))
    end

    def generate_stop_event?
      # If app is not in started state and/or is new, then the changes
      # to the footprint shouldn't trigger a billing event.
      !new? &&
          (being_stopped? || (footprint_changed? && started?)) &&
          !has_stop_event_for_latest_run?
    end

    def in_suspended_org?
      space.in_suspended_org?
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

    def organization
      space && space.organization
    end

    def has_stop_event_for_latest_run?
      latest_run_id = AppStartEvent.filter(:app_guid => guid).order(Sequel.desc(:id)).select_map(:app_run_id).first
      !!AppStopEvent.find(:app_run_id => latest_run_id)
    end

    def before_destroy
      lock!
      self.state = "STOPPED"
      super
    end

    def after_destroy
      AppStopEvent.create_from_app(self) unless initial_value(:state) == "STOPPED" || has_stop_event_for_latest_run?
      create_app_usage_event
    end

    def after_destroy_commit
      super
      AppObserver.deleted(self)
    end

    def command=(cmd)
      self.metadata ||= {}
      self.metadata["command"] = (cmd.nil? || cmd.empty?) ? nil : cmd
    end

    def command
      self.metadata && self.metadata["command"]
    end

    def detected_start_command
      cmd = command || current_droplet.detected_start_command
      cmd.nil? ? '' : cmd
    end

    def console=(c)
      self.metadata ||= {}
      self.metadata["console"] = c
    end

    def console
      # without the == true check, this expression can return nil if
      # the key doesn't exist, rather than false
      self.metadata && self.metadata["console"] == true
    end

    def debug=(d)
      self.metadata ||= {}
      # We don't support sending nil through API
      self.metadata["debug"] = (d == "none") ? nil : d
    end

    def debug
      self.metadata && self.metadata["debug"]
    end

    # We sadly have to do this ourselves because the serialization plugin
    # doesn't play nice with the dirty plugin, and we want the dirty plugin
    # more
    def environment_json=(env)
      json = Yajl::Encoder.encode(env)
      generate_salt
      self.encrypted_environment_json =
          VCAP::CloudController::Encryptor.encrypt(json, salt)
    end

    def environment_json
      return unless encrypted_environment_json

      Yajl::Parser.parse(
          VCAP::CloudController::Encryptor.decrypt(
              encrypted_environment_json, salt))
    end

    def system_env_json
      vcap_services
    end

    def vcap_application
      {
          limits: {
              mem: memory,
              disk: disk_quota,
              fds: file_descriptors
          },
          application_version: version,
          application_name: name,
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
      service_uris = service_bindings.map { |binding| binding.credentials["uri"] }.compact
      DatabaseUriGenerator.new(service_uris).database_uri
    end

    def validate_route(route)
      objection = Errors::InvalidRouteRelation.new(route.guid)

      raise objection if route.nil?
      raise objection if space.nil?
      raise objection if route.space_id != space.id

      raise objection unless route.domain.usable_by_organization?(space.organization)
    end

    def custom_buildpacks_enabled?
      !VCAP::CloudController::Config.config[:disable_custom_buildpacks]
    end

    def requested_instances
      default_instances = db_schema[:instances][:default].to_i
      instances ? instances : default_instances
    end

    def max_app_disk_in_mb
      VCAP::CloudController::Config.config[:maximum_app_disk_in_mb]
    end

    def requested_memory
      memory ? memory : VCAP::CloudController::Config.config[:default_app_memory]
    end

    def additional_memory_requested
      total_requested_memory = requested_memory * requested_instances

      return total_requested_memory if new?

      app = app_from_db
      total_existing_memory = app[:memory] * app[:instances]
      total_requested_memory - total_existing_memory
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
      binding.destroy
    end

    def self.user_visibility_filter(user)
      Sequel.or([
                    [:space, user.spaces_dataset],
                    [:space, user.managed_spaces_dataset],
                    [:space, user.audited_spaces_dataset],
                    [:apps__space_id, user.managed_organizations_dataset.join(:spaces, :spaces__organization_id => :organizations__id).select(:spaces__id)]
                ])
    end

    def needs_staging?
      package_hash && !staged? && started? && instances > 0
    end

    def staged?
      self.package_state == "STAGED"
    end

    def staging_failed?
      self.package_state == "FAILED"
    end

    def pending?
      self.package_state == "PENDING"
    end

    def started?
      self.state == "STARTED"
    end

    def stopped?
      self.state == "STOPPED"
    end

    def uris
      routes.map(&:fqdn)
    end

    def mark_as_failed_to_stage(reason="StagingError")
      self.package_state = "FAILED"
      self.staging_failed_reason = reason
      save
    end

    def mark_for_restaging
      self.package_state = "PENDING"
      self.staging_failed_reason = nil
    end

    def buildpack
      if admin_buildpack
        return admin_buildpack
      elsif super
        return GitBasedBuildpack.new(super)
      end

      AutoDetectionBuildpack.new
    end

    def buildpack=(buildpack_name)
      self.admin_buildpack = nil
      super(nil)
      admin_buildpack = Buildpack.find(name: buildpack_name.to_s)

      if admin_buildpack
        self.admin_buildpack = admin_buildpack
      elsif buildpack_name != "" #git url case
        super(buildpack_name)
      end
    end

    def custom_buildpack_url
      buildpack.url if buildpack.custom?
    end

    def package_hash=(hash)
      super(hash)
      mark_for_restaging if column_changed?(:package_hash)
    end

    def stack=(stack)
      mark_for_restaging unless new?
      super(stack)
    end

    def droplet_hash=(hash)
      if hash
        self.package_state = "STAGED"
      end
      super(hash)
    end

    def add_new_droplet(hash)
      self.droplet_hash = hash
      add_droplet(droplet_hash: hash)
      self.save
    end

    def current_droplet
      return nil unless droplet_hash
      self.droplets_dataset.filter(droplet_hash: droplet_hash).first ||
          Droplet.new(app: self, droplet_hash: self.droplet_hash)
    end

    def start!
      self.state = "STARTED"
      save
    end

    def stop!
      self.state = "STOPPED"
      save
    end

    def restage!
      stop!
      mark_for_restaging
      start!
    end

    # returns True if we need to update the DEA's with
    # associated URL's.
    # We also assume that the relevant methods in +DeaClient+ will reset
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
        UndoAppChanges.new(self).undo(previous_changes)
        raise e
      end
    end

    def to_hash(opts={})
      if !VCAP::CloudController::SecurityContext.admin? && !space.developers.include?(VCAP::CloudController::SecurityContext.current_user)
        opts.merge!({redact: ['environment_json', 'system_env_json']})
      end
      super(opts)
    end

    private

    def metadata_deserialized
      deserialized_values[:metadata]
    end

    def app_from_db
      error_message = "Expected app record not found in database with guid %s"
      app_from_db = self.class.find(guid: guid)
      if app_from_db.nil?
        self.class.logger.fatal("app.find.missing", guid: guid, self: inspect)
        raise Errors::ApplicationMissing, error_message % guid
      end
      app_from_db
    end

    WHITELIST_SERVICE_KEYS = %W[name label tags plan credentials syslog_drain_url].freeze

    def service_binding_json (binding)
      vcap_service = {}
      WHITELIST_SERVICE_KEYS.each do |key|
        vcap_service[key] = binding[key.to_sym] if binding[key.to_sym]
      end
      vcap_service
    end

    def vcap_services
      services_hash = {}
      self.service_bindings.each do |sb|
        binding = ServiceBindingPresenter.new(sb).to_hash
        service = service_binding_json(binding)
        services_hash[binding[:label]] ||= []
        services_hash[binding[:label]] << service
      end
      {"VCAP_SERVICES" => services_hash}
    end

    def health_manager_client
      CloudController::DependencyLocator.instance.health_manager_client
    end

    def mark_routes_changed(_)
      @routes_changed = true

      set_new_version
      save
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt.freeze
    end

    def app_usage_event_repository
      @repository ||= Repositories::Runtime::AppUsageEventRepository.new
    end

    def create_app_usage_buildpack_event
      return unless staged? && started?
      app_usage_event_repository.create_from_app(self, "BUILDPACK_SET")
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
        @logger ||= Steno.logger("cc.models.app")
      end
    end
  end
  # rubocop:enable ClassLength
end
