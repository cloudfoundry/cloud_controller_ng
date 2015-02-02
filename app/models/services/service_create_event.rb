module VCAP::CloudController
  class ServiceCreateEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
      :space_guid,
      :space_name,
      :service_instance_guid,
      :service_instance_name,
      :service_guid,
      :service_label,
      :service_provider,
      :service_version,
      :service_plan_guid,
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
      validates_presence :service_plan_guid
      validates_presence :service_plan_name
    end

    def event_type
      'service_create'
    end

    def self.create_from_service_instance(instance)
      return if instance.user_provided_instance?

      plan = instance.service_plan
      svc = plan.service
      space = instance.space
      org = space.organization

      return unless org.billing_enabled?
      ServiceCreateEvent.create(
        timestamp: Sequel::CURRENT_TIMESTAMP,
        organization_guid: org.guid,
        organization_name: org.name,
        space_guid: space.guid,
        space_name: space.name,
        service_instance_guid: instance.guid,
        service_instance_name: instance.name,
        service_guid: svc.guid,
        service_label: svc.label,
        service_provider: svc.provider,
        service_version: svc.version,
        service_plan_guid: plan.guid,
        service_plan_name: plan.name,
      )
    end
  end
end
