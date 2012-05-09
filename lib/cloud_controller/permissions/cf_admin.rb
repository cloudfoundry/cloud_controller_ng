# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class CFAdmin
    def self.granted_to?(user)
      !user.nil? && user.admin?
    end

    VCAP::CloudController::Permissions::register self
  end
end
