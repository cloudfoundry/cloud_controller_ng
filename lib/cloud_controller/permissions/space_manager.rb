# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class SpaceManager < SpacePermissions

    def self.granted_to?(obj, user)
      granted_to_via_space?(obj, user, :managers)
    end

    Permissions::register self
  end
end
