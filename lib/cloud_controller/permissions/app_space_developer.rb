# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class AppSpaceDeveloper < AppSpacePermissions

    def self.granted_to?(obj, user)
      granted_to_via_app_space?(obj, user, :developers)
    end

    VCAP::CloudController::Permissions::register self
  end
end
