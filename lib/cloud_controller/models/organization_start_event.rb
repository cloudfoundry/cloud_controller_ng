# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class OrganizationStartEvent < BillingEvent
    class BillingNotEnabled < RuntimeError; end

    export_attributes(
      :timestamp,
      :event_type,
      :organization_guid,
      :organization_name,
    )

    def event_type
      "organization_billing_start"
    end

    def self.create_from_org(org)
      raise BillingNotEnabled unless org.billing_enabled?
      OrganizationStartEvent.create(
        :timestamp => Time.now,
        :organization_guid => org.guid,
        :organization_name => org.name,
      )
    end
  end
end
