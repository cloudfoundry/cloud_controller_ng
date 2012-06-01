# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class Auditor
    def self.granted_to?(obj, user)
      obj.kind_of?(VCAP::CloudController::Models::Organization) &&
        !user.nil? && obj.auditors.include?(user)
    end

    VCAP::CloudController::Permissions::register self
  end
end
