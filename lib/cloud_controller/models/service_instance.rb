# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end

    many_to_one :service_plan
    many_to_one :app_space
    one_to_many :service_bindings, :before_add => :validate_service_binding

    default_order_by  :id

    export_attributes :id, :name, :credentials, :service_plan_id,
                      :app_space_id, :vendor_data, :service_binding_ids,
                      :created_at, :updated_at

    import_attributes :name, :credentials, :service_plan_id,
                      :app_space_id, :vendor_data

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :credentials
      validates_presence :app_space
      validates_presence :service_plan
      validates_unique   [:app_space_id, :name]
    end

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.app_space != app_space
        # FIXME: unlike most other validations, this is *NOT* being enforced
        # by the underlying db.
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end
  end
end
