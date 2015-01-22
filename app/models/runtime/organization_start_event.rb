module VCAP::CloudController
  class OrganizationStartEvent < BillingEvent
    class BillingNotEnabled < RuntimeError; end

    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
    )

    def event_type
      'organization_billing_start'
    end

    def self.create_from_org(org)
      raise BillingNotEnabled unless org.billing_enabled?
      OrganizationStartEvent.create(
        timestamp: Sequel::CURRENT_TIMESTAMP,
        organization_guid: org.guid,
        organization_name: org.name,
      )
    end
  end
end
