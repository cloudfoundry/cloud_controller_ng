# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class SpacePermissions
    include VCAP::CloudController

    def self.granted_to_via_space?(obj, user, relation)
      return false if user.nil?

      if obj.kind_of?(Models::Space)
        obj.send(relation).include?(user)
      elsif !obj.new? && obj.respond_to?(:spaces)
        obj.spaces_dataset.filter(relation => [user]).count >= 1
      elsif !obj.new? && obj.respond_to?(:space)
        obj.space.send("#{relation}_dataset")[user.id] != nil
      end
    end
  end
end
