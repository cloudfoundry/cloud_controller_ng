# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class OrgUser < OrgPermissions
    def self.granted_to?(obj, user)
      granted_to_via_org?(obj, user, :users)
    end

    VCAP::CloudController::Permissions::register self
  end
end
