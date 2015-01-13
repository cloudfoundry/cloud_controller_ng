module VCAP::CloudController
  class AppStartEvent < BillingEvent
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
      validates_unique :app_run_id
    end

    def event_type
      'app_start'
    end

    def self.create_from_app(app)
      return unless app.space.organization.billing_enabled?
      AppStartEvent.create(
        timestamp: Sequel::CURRENT_TIMESTAMP,
        organization_guid: app.space.organization_guid,
        organization_name: app.space.organization.name,
        space_guid: app.space.guid,
        space_name: app.space.name,
        app_guid: app.guid,
        app_name: app.name,
        app_run_id: SecureRandom.uuid,
        app_plan_name: app.production ? 'paid' : 'free',
        app_memory: app.memory,
        app_instance_count: app.instances,
      )
    end
  end
end
