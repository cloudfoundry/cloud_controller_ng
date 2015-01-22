module VCAP::CloudController
  class ServiceDeleteEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
      :space_guid,
      :space_name,
      :service_instance_guid,
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
      'service_delete'
    end

    def self.create_from_service_instance(instance)
      plan = instance.service_plan
      plan.service
      space = instance.space
      org = space.organization

      return unless org.billing_enabled?
      ServiceDeleteEvent.create(
        timestamp: Sequel::CURRENT_TIMESTAMP,
        organization_guid: org.guid,
        organization_name: org.name,
        space_guid: space.guid,
        space_name: space.name,
        service_instance_guid: instance.guid,
        service_instance_name: instance.name,
      )
    end
  end
end
