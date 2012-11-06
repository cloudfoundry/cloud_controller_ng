# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class AppStartEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_id,
      :organization_name,
      :space_id,
      :space_name,
      :app_id,
      :app_name,
      :app_run_id,
      :app_plan_name,
      :app_memory,
      :app_instance_count,
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :app_guid
      validates_presence :app_name
      validates_presence :app_run_id
      validates_presence :app_plan_name
      validates_presence :app_memory
      validates_presence :app_instance_count
    end

    def event_type
      "app_start"
    end
  end
end
