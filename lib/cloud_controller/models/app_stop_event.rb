# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class MissingAppStartEvent < StandardError; end

  class AppStopEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
      :space_guid,
      :space_name,
      :app_guid,
      :app_name,
      :app_run_id,
    )

    def validate
      super
      validates_presence :space_guid
      validates_presence :space_name
      validates_presence :app_guid
      validates_presence :app_name
      validates_unique   :app_run_id
    end

    def event_type
      "app_stop"
    end

    def self.create_from_app(app)
      return unless app.space.organization.billing_enabled?
      app_start_event =  AppStartEvent.filter(:app_guid => app.guid).order(Sequel.desc(:timestamp)).first
      raise MissingAppStartEvent.new(app.guid) if app_start_event.nil?

      AppStopEvent.create(
        :timestamp => Time.now,
        :organization_guid => app.space.organization_guid,
        :organization_name => app.space.organization.name,
        :space_guid => app.space.guid,
        :space_name => app.space.name,
        :app_guid => app.guid,
        :app_name => app.name,
        :app_run_id => app_start_event.app_run_id,
      )
    end
  end
end
