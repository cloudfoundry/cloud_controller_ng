# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end

    many_to_one :service_plan
    many_to_one :space
    one_to_many :service_bindings, :before_add => :validate_service_binding

    default_order_by  :id

    export_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :vendor_data

    import_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :vendor_data

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :credentials
      validates_presence :space
      validates_presence :service_plan
      validates_unique   [:space_id, :name]
    end

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        # FIXME: unlike most other validations, this is *NOT* being enforced
        # by the underlying db.
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end

    def credentials=(val)
       val = Yajl::Encoder.encode(val)
       super(val)
    end

    def credentials
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :space => user.spaces_dataset)
    end
  end
end
