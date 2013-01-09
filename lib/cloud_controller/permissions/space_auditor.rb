# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class SpaceAuditor < SpacePermissions

    def self.granted_to?(obj, user, roles)
      granted_to_via_space?(obj, user, :auditors)
    end

    VCAP::CloudController::Permissions::register self
  end
end
