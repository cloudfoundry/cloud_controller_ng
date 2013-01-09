# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class Authenticated
    def self.granted_to?(obj, user, roles)
      !user.nil? || roles.present?
    end

    VCAP::CloudController::Permissions::register self
  end
end
