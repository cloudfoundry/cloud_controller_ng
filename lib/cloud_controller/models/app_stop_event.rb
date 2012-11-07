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

    def self.create_from_app(app)
      return unless app.space.organization.billing_enabled?
      AppStopEvent.create(
        :timestamp => Time.now,
        :organization_guid => app.space.organization_guid,
        :organization_name => app.space.organization.name,
        :space_guid => app.space.guid,
        :space_name => app.space.name,
        :app_guid => app.guid,
        :app_name => app.name,
        :app_run_id => app.version,
      )
    end
  end
end
