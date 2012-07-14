# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class AppSpacePermissions
    include VCAP::CloudController

    def self.granted_to_via_app_space?(obj, user, relation)
      return false if user.nil?

      if obj.kind_of?(Models::AppSpace)
        obj.send(relation).include?(user)
      elsif !obj.new? && obj.respond_to?(:app_spaces)
        obj.app_spaces_dataset.filter(relation => [user]).count >= 1
      elsif !obj.new? && obj.respond_to?(:app_space)
        obj.app_space.send("#{relation}_dataset")[user.id] != nil
      end
    end
  end
end
