# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class OrgPermissions
    include VCAP::CloudController

    def self.granted_to_via_org?(obj, user, relation)
      return false if user.nil?

      if obj.kind_of?(Models::Organization)
        obj.send(relation).include?(user)
      elsif !obj.new?
        if (obj.respond_to?(:organizations) &&
            obj.organizations_dataset.filter(relation => [user]).count >= 1)
          return true
        end
        if (obj.respond_to?(:organization) && obj.organization &&
            obj.organization.send("#{relation}_dataset")[user.id] != nil)
          return true
        end
      end
    end
  end
end
