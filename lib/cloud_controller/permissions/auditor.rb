# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class Auditor < OrgPermissions
    def self.granted_to?(obj, user, roles)
      granted_to_via_org?(obj, user, :auditors)
    end

    VCAP::CloudController::Permissions::register self
  end
end
