require "cloud_controller/app_manager"

module VCAP::CloudController
  module Models
    class App < Sequel::Model
      plugin :serialization

      class InvalidRouteRelation < InvalidRelation
        def to_s
          "The URL was not available [route ID #{super}]"
        end
      end

      class InvalidBindingRelation < InvalidRelation;
      end

      class AlreadyDeletedError < StandardError; end

      dataset_module do
        def existing
          filter(not_deleted: true)
        end

        def deleted
          unfiltered.filter(not_deleted: nil)
        end

        def with_deleted
          unfiltered
        end
      end

      set_dataset(existing)

      one_to_many       :service_bindings, :after_remove => :after_remove_binding
      one_to_many       :events, :class => VCAP::CloudController::Models::AppEvent

      many_to_one       :space
      many_to_one       :stack

      many_to_many      :routes, :before_add => :validate_route, :after_add => :mark_routes_changed, :after_remove => :mark_routes_changed

      add_association_dependencies :routes => :nullify,
        :service_bindings => :destroy, :events => :destroy

      default_order_by :name

      export_attributes :name, :production,
        :space_guid, :stack_guid, :buildpack, :detected_buildpack,
        :environment_json, :memory, :instances, :disk_quota,
        :state, :version, :command, :console, :debug,
        :staging_task_id

      import_attributes :name, :production,
        :space_guid, :stack_guid, :buildpack, :detected_buildpack,
        :environment_json, :memory, :instances, :disk_quota,
        :state, :command, :console, :debug,
        :staging_task_id, :service_binding_guids, :route_guids

      strip_attributes :name

      serialize_attributes :json, :metadata

      APP_STATES = %w[STOPPED STARTED].map(&:freeze).freeze
      PACKAGE_STATES = %w[PENDING STAGED FAILED].map(&:freeze).freeze

      AUDITABLE_FIELDS = [:environment_json, :instances, :memory, :state, :name]
      CENSORED_FIELDS =  [:environment_json]

      CENSORED_MESSAGE = "PRIVATE DATA HIDDEN".freeze

      def auditable_changes
        previous_changes.slice(*AUDITABLE_FIELDS).tap do |changes|
          CENSORED_FIELDS.each do |censored|
            changes[censored] = [CENSORED_MESSAGE] * 2 if changes.has_key?(censored)
          end
        end
      end

      def auditable_values
        values.slice(*AUDITABLE_FIELDS).tap do |changes|
          CENSORED_FIELDS.each do |censored|
            changes[censored] = CENSORED_MESSAGE if changes.has_key?(censored)
          end
        end
      end

      # marked as true on changing the associated routes, and reset by
      # +DeaClient.start+
      attr_accessor :routes_changed

      # Last staging response which will contain streaming log url
      attr_accessor :last_stager_response

      alias :kill_after_multiple_restarts? :kill_after_multiple_restarts

      def validate
        validates_presence :name
        validates_presence :space
        validates_unique   [:space_id, :name], :where => proc { |ds, obj, cols| ds.filter(:not_deleted => true, :space_id => obj.space_id, :name => obj.name) }

        validates_git_url :buildpack

        validates_includes PACKAGE_STATES, :package_state, :allow_missing => true
        validates_includes APP_STATES, :state, :allow_missing => true

        validate_environment
        validate_metadata
        check_memory_quota
      end

      def before_create
        super
        self.version = SecureRandom.uuid unless self.version
      end

      def before_save
        if generate_start_event? && !package_hash
          raise VCAP::Errors::AppPackageInvalid.new(
            "bits have not been uploaded")
        end

        super

        self.stack ||= Stack.default

        # The reason this is only done on a state change is that we really only
        # care about the state when we transitioned from stopped to running.  The
        # current semantics of changing memory or bindings is that they don't
        # take effect until after the app is restarted.  This allows clients to
        # batch a bunch of changes without having their app bounce.  If we were
        # to change the version on every metadata change, the hm would cause them
        # to get restarted prematurely.
        #
        # The dirty check on version allows a higher level to set the version.
        # We might start populating this with the vcap request guid of an api
        # request.
        if (column_changed?(:state) || column_changed?(:memory)) && started?
          self.version = SecureRandom.uuid if !column_changed?(:version)
        end

        AppStopEvent.create_from_app(self) if generate_stop_event?
        AppStartEvent.create_from_app(self) if generate_start_event?
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

      def being_stopped?
        column_changed?(:state) && stopped?
      end

      def has_stop_event_for_latest_run?
        latest_run_id = AppStartEvent.filter(:app_guid => guid).order(Sequel.desc(:id)).select_map(:app_run_id).first
        !!AppStopEvent.find(:app_run_id => latest_run_id)
      end

      def footprint_changed?
        (column_changed?(:production) || column_changed?(:memory) ||
          column_changed?(:instances))
      end

      def after_destroy
        AppStopEvent.create_from_app(self) unless stopped? || has_stop_event_for_latest_run?
      end

      def after_destroy_commit
        AppManager.stop_droplet(self)
        AppManager.delete_droplet(self)
        AppPackage.delete_package(self.guid)
      end

      def command=(cmd)
        self.metadata ||= {}
        self.metadata["command"] = cmd
      end

      def command
        self.metadata && self.metadata["command"]
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
        self.encrypted_environment_json = VCAP::CloudController::Encryptor.encrypt(json, salt)
        super(json)
      end

      def environment_json
        if encrypted_environment_json
          json = VCAP::CloudController::Encryptor.decrypt(encrypted_environment_json, salt)
        else
          json = super
        end

        json.nil? ? nil : Yajl::Parser.parse(json)
      end

      def validate_environment
        return if environment_json.nil?
        unless environment_json.kind_of?(Hash)
          errors.add(:environment_json, :invalid_environment)
          return
        end
        environment_json.keys.each do |k|
          errors.add(:environment_json, "reserved_key:#{k}") if k =~ /^(vcap|vmc)_/i
        end
      rescue Yajl::ParseError
        errors.add(:environment_json, :invalid_json)
      end

      def validate_metadata
        m = deserialized_values[:metadata]
        return if m.nil?
        unless m.kind_of?(Hash)
          errors.add(:metadata, :invalid_metadata)
        end
      end

      def validate_route(route)
        unless (route && space &&
          route.domain_dataset.filter(:spaces => [space]).count == 1 &&
          route.space_id == space.id)
          raise InvalidRouteRelation.new(route.guid)
        end
      end

      def additional_memory_requested
        default_instances = db_schema[:instances][:default].to_i

        num_instances = instances ? instances : default_instances
        total_requested_memory = requested_memory * num_instances

        return total_requested_memory if new?

        app_from_db = self.class.find(:guid => guid)
        total_existing_memory = app_from_db[:memory] * app_from_db[:instances]
        additional_memory = total_requested_memory - total_existing_memory
        return additional_memory if additional_memory > 0
        0
      end

      def check_memory_quota
        errors.add(:memory, :zero_or_less ) unless requested_memory > 0

        if space && (space.organization.memory_remaining < additional_memory_requested)
          errors.add(:memory, :quota_exceeded)
        end
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

      # When hard-deleting apps through spaces, we need to include soft-deleted apps
      def _delete_dataset
        self.class.with_deleted.filter(:id => id)
      end

      def self.user_visibility_filter(user)
        user_visibility_filter_with_admin_override(:space => user.spaces_dataset)
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

      def deleted?
        !self.not_deleted
      end

      def nullifyable_association_names
        @nullifyable_association_names ||= model.association_dependencies_hash.select do |association, action|
          action == :nullify
        end.keys
      end

      def has_deletable_associations?
        deletable_association_names.each do |association|
          data = send(association)
          return true unless data.nil? || data.empty?
        end

        false
      end

      # We do NOT delete app events for audit reasons.
      def deletable_association?(association)
        association != :events
      end

      def deletable_association_names
        @deletable_association_names ||= model.association_dependencies_hash.select do |association, action|
          action == :destroy && deletable_association?(association)
        end.keys
      end

      def cleanup_deletable_associations
        deletable_association_names.each do |association|
          data = send(association)
          data = [data] unless data.kind_of?(Array)
          data.each do |associated_obj|
            associated_obj.destroy
          end
        end
      end

      def cleanup_nullifyable_associations
        nullifyable_association_names.each do |association|
          data = send(association)
          if data.kind_of?(Array)
            data.each do |associated_obj|
              associated_obj.remove_app(self) if associated_obj.respond_to?(:remove_app)
            end
          else
            data.app = nil
          end
        end
      end

      def cleanup_associations
        cleanup_deletable_associations
        cleanup_nullifyable_associations
      end

      def soft_delete
        raise AlreadyDeletedError, "App: #{self} was already soft deleted on: #{deleted_at}" if deleted_at

        model.db.transaction do
          lock!
          cleanup_associations
          self.deleted_at = Time.now
          self.not_deleted = nil
          save

          after_destroy
        end

        AppManager.stop_droplet(self)
      end

      def uris
        routes.map { |r| r.fqdn }
      end

      def after_remove_binding(binding)
        mark_for_restaging
      end

      def mark_as_failed_to_stage
        self.package_state = "FAILED"
        save
      end

      def mark_for_restaging(opts={})
        self.package_state = "PENDING"
        save if opts[:save]
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
        self.package_state = "STAGED" if hash
        super(hash)
      end

      def running_instances
        return 0 unless started?
        health_manager_client.healthy_instances(self)
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
        AppManager.app_changed(self, previous_changes || {})
      end

      private

      def health_manager_client
        @health_manager_client ||= CloudController::DependencyLocator.instance.health_manager_client
      end

      def requested_memory
        default_memory = db_schema[:memory][:default].to_i
        memory ? memory : default_memory
      end

      def mark_routes_changed(_)
        @routes_changed = true
      end

      def generate_salt
        self.salt ||= VCAP::CloudController::Encryptor.generate_salt.freeze
      end
    end
  end
end
