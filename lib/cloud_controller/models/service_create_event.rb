# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceCreateEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_id,
      :organization_name,
      :space_id,
      :space_name,
      :service_instance_id,
      :service_instance_name,
      :service_id,
      :service_label,
      :service_provider,
      :service_version,
      :service_plan_id,
      :service_plan_name,
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :service_instance_guid
      validates_presence :service_instance_name
      validates_presence :service_guid
      validates_presence :service_label
      validates_presence :service_provider
      validates_presence :service_version
      validates_presence :service_plan_guid
      validates_presence :service_plan_name
    end

    def event_type
      "service_create"
    end
  end
end
