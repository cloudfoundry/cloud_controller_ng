# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class OrganizationStartEvent < BillingEvent
    export_attributes(
      :timestamp,
      :event_type,
      :organization_id,
      :organization_name,
    )

    def event_type
      "organization_billing_start"
    end
  end
end
