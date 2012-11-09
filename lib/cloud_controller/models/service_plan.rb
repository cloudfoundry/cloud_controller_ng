# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServicePlan < Sequel::Model
    many_to_one       :service
    one_to_many       :service_instances

    default_order_by  :name

    export_attributes :name, :description, :service_guid

    import_attributes :name, :description, :service_guid

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_presence :service
      validates_unique   [:service_id, :name]
    end
  end
end
