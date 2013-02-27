# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/app_stager"

module VCAP::CloudController
  module Models
    class App < Sequel::Model
      plugin :serialization

      class InvalidRouteRelation < InvalidRelation; end
      class InvalidBindingRelation < InvalidRelation; end

      many_to_one       :space
      many_to_one       :framework
      many_to_one       :runtime
      many_to_many      :routes,
                        :before_add => :validate_route,
                        :after_add => :mark_routes_changed,
                        :after_remove => :mark_routes_changed
      one_to_many       :service_bindings, :after_remove => :after_remove_binding
      many_to_many      :service_instances, :join_table => :service_bindings

      add_association_dependencies :routes => :nullify, :service_bindings => :destroy

      default_order_by  :name

      export_attributes :name, :production,
                        :space_guid, :framework_guid, :runtime_guid, :buildpack,
                        :environment_json, :memory, :instances,
                        :disk_quota, :state, :version, :command, :console, :debug

      import_attributes :name, :production,
                        :space_guid, :framework_guid, :runtime_guid, :buildpack,
                        :environment_json, :memory, :instances,
                        :disk_quota, :state,
                        :command, :console, :debug,
                        :service_binding_guids, :route_guids

      strip_attributes  :name

      serialize_attributes :json, :metadata

      AppStates = %w[STOPPED STARTED].map(&:freeze).freeze
      PackageStates = %w[PENDING STAGED FAILED].map(&:freeze).freeze

      # marked as true on changing the associated routes, and reset by
      # +DeaClient.start+
      attr_accessor :routes_changed

      attr_accessor :stage_async

      # Last staging response which might contain streaming log url
      attr_accessor :last_stager_response

      def before_validation
        # TODO: Once VMC deprecates frameworks
        # and runtimes we can remove frameworks and runtimes completely from cc.
        self.framework ||= VCAP::CloudController::Models::Framework.find(:name => "buildpack")
        self.runtime ||= VCAP::CloudController::Models::Runtime.find(:name => "ruby19")
        super
      end

      def validate
        # TODO: if we move the defaults out of the migration and up to the
        # controller (as it probably should be), do more presence validation
        # here
        validates_presence :name
        validates_presence :space
        validates_presence :framework
        validates_presence :runtime
        validates_git_url :buildpack
        validates_unique   [:space_id, :name]
        validates_includes PackageStates, :package_state, :allow_missing => true
        validates_includes AppStates, :state, :allow_missing => true
        validate_environment
        validate_metadata
        check_memory_quota
      end

      def before_create
        super
        self.version = SecureRandom.uuid unless self.version
      end

      def before_save
        super

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
        !new? && ((column_changed?(:state) && stopped?) ||
                  (footprint_changed? && started?))
      end

      def footprint_changed?
        (column_changed?(:production) || column_changed?(:memory) ||
         column_changed?(:instances))
      end

      def after_destroy_commit
        VCAP::CloudController::DeaClient.stop(self) if started?
        VCAP::CloudController::AppStager.delete_droplet(self)
        VCAP::CloudController::AppPackage.delete_package(self.guid)
        AppStopEvent.create_from_app(self) unless stopped?
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
        super(json)
      end

      def environment_json
        json = super
        if json
          Yajl::Parser.parse(json)
        end
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
        default_memory = db_schema[:memory][:default].to_i
        default_instances = db_schema[:instances][:default].to_i

        mem = memory ? memory : default_memory
        num_instances = instances ? instances : default_instances
        total_requested_memory = mem * num_instances

        return total_requested_memory if new?

        app_from_db = self.class.find(:guid => guid)
        total_existing_memory = app_from_db[:memory] * app_from_db[:instances]
        additional_memory = total_requested_memory - total_existing_memory
        return additional_memory if additional_memory > 0
        0
      end

      def check_memory_quota
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

      def self.user_visibility_filter(user)
        user_visibility_filter_with_admin_override(:space => user.spaces_dataset)
      end

      def needs_staging?
        !(self.package_hash.nil? || self.staged?)
      end

      def staged?
        self.package_state == "STAGED"
      end

      def started?
        self.state == "STARTED"
      end

      def stopped?
        self.state == "STOPPED"
      end

      def uris
        routes.map { |r| r.fqdn }
      end

      def after_remove_binding(binding)
        mark_for_restaging
      end

      def mark_for_restaging(should_save=true)
        self.package_state = "PENDING"
        save if should_save
      end

      def package_hash=(hash)
        super(hash)
        mark_for_restaging(false) if column_changed?(:package_hash)
      end

      def droplet_hash=(hash)
        # TODO: rename package_state to just state?
        self.package_state = "STAGED"
        super(hash)
      end

      def running_instances
        return 0 unless started?
        VCAP::CloudController::HealthManagerClient.healthy_instances(self)
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
        react_to_saved_changes(previous_changes || {})
      end

      private

      def stage_if_needed(&success_callback)
        if needs_staging? && started?
          self.last_stager_response = \
            AppStager.stage_app(self, {:async => stage_async}, &success_callback)
        else
          success_callback.call
        end
      end

      def react_to_saved_changes(changes)
        if changes.has_key?(:state)
          react_to_state_change
        elsif changes.has_key?(:instances)
          delta = changes[:instances][1] - changes[:instances][0]
          react_to_instances_change(delta)
        end
      end

      def react_to_state_change
        if started?
          stage_if_needed do
            DeaClient.start(self)
            send_droplet_updated_message
          end
        elsif stopped?
          DeaClient.stop(self)
          send_droplet_updated_message
        end
      end

      def react_to_instances_change(delta)
        if started?
          stage_if_needed do
            DeaClient.change_running_instances(self, delta)
            send_droplet_updated_message
          end
        end
      end

      def send_droplet_updated_message
        MessageBus.instance.publish("droplet.updated", Yajl::Encoder.encode(
          :droplet => guid,
          :cc_partition => MessageBus.instance.config[:cc_partition]
        ))
      end

      # @param  [Hash, nil] old
      # @param  [Hash, nil] new
      # @return [Boolean]   old and new values of the key differ, or the key was added or removed
      def key_changed?(key, old, new)
        if old.nil? || ! old.has_key?(key)
          return new && new.has_key?(key)
        else
          new.nil? || ! new.has_key?(key) || old[key] != new[key]
        end
      end

      def mark_routes_changed(_)
        @routes_changed = true
      end
    end
  end
end
