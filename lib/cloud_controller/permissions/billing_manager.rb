# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class BillingManager < OrgPermissions
    def self.granted_to?(obj, user, roles)
      granted_to_via_org?(obj, user, :billing_managers)
    end

    VCAP::CloudController::Permissions::register self
  end
end
