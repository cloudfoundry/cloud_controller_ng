# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class Anonymous
    def self.granted_to?(obj, user, roles)
      user.nil? && roles.none?
    end

    VCAP::CloudController::Permissions::register self
  end
end
