# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class AppStopEvent < BillingEvent
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
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :app_guid
      validates_presence :app_name
    end

    def event_type
      "app_stop"
    end
  end
end
