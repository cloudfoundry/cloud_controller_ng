# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class OrgManager
    def self.granted_to?(obj, user)
      return false if user.nil?

      if obj.kind_of?(VCAP::CloudController::Models::Organization)
        obj.managers.include?(user)
      elsif obj.respond_to?(:organization)
        obj.organization && obj.organization.managers.include?(user)
      end
    end

    VCAP::CloudController::Permissions::register self
  end
end
