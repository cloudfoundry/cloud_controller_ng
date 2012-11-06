# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceDeleteEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_id,
      :organization_name,
      :space_id,
      :space_name,
      :service_instance_id,
      :service_instance_name,
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :service_instance_guid
      validates_presence :service_instance_name
    end

    def event_type
      "service_delete"
    end
  end
end
