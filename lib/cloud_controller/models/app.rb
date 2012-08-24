# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class App < Sequel::Model
    class InvalidRelation      < StandardError; end
    class InvalidRouteRelation < InvalidRelation; end
    class InvalidBindingRelation < InvalidRelation; end

    many_to_one       :space
    many_to_one       :framework
    many_to_one       :runtime
    many_to_many      :routes, :before_add => :validate_route
    one_to_many       :service_bindings, :after_remove => :after_remove_binding

    add_association_dependencies :routes => :nullify, :service_bindings => :destroy

    default_order_by  :name

    export_attributes :name, :production,
                      :space_guid, :framework_guid, :runtime_guid,
                      :environment_json, :memory, :instances, :file_descriptors,
                      :disk_quota, :state, :version

    import_attributes :name, :production,
                      :space_guid, :framework_guid, :runtime_guid,
                      :environment_json, :memory, :instances,
                      :file_descriptors, :disk_quota, :state,
                      :service_binding_guids, :route_guids

    strip_attributes  :name

    def validate
      # TODO: if we move the defaults out of the migration and up to the
      # controller (as it probably should be), do more presence validation
      # here
      validates_presence :name
      validates_presence :space
      validates_presence :framework
      validates_presence :runtime
      validates_unique   [:space_id, :name]
      validate_environment
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
      if column_changed?(:state) && !column_changed?(:version)
        self.version = SecureRandom.uuid
      end
    end

    def environment_json=(val)
      val = Yajl::Encoder.encode(val)
      super(val)
    end

    def validate_environment
      return if environment_json.nil?
      h = Yajl::Parser.parse(environment_json)
      errors.add(:environment_json, :invalid_json) unless h.kind_of?(Hash)
      h.keys.each do |k|
        errors.add(:environment_json, "reserved_key:#{k}") if k =~ /^(vcap|vmc)_/i
      end
    rescue Yajl::ParseError
      errors.add(:environment_json, :invalid_json)
    end

    def validate_route(route)
      unless route && space && route.domain.spaces.include?(space)
        raise InvalidRouteRelation.new(route.guid)
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

    def mark_for_restaging
      self.package_state = "PENDING"
      save
    end

    def package_hash=(hash)
      mark_for_restaging unless self.package_hash == hash
      super(hash)
    end

    def droplet_hash=(hash)
      # TODO: rename package_state to just state?
      self.package_state = "STAGED"
      super(hash)
    end
  end
end
