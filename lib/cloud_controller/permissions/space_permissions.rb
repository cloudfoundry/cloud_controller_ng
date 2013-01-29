# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class SpacePermissions
    include VCAP::CloudController

    def self.granted_to_via_space?(obj, user, relation)
      return false if user.nil?

      space_contains?(obj, user, relation) ||
        related_space_contains_user?(obj, user, relation) ||
        any_related_space_contains_user?(obj, user, relation)
    end

    def self.space_contains?(obj, user, relation)
      if obj.kind_of?(Models::Space)
        obj.send(relation).include?(user)
      end
    end

    def self.any_related_space_contains_user?(obj, user, relation)
      if !obj.new? && obj.respond_to?(:spaces)
        obj.spaces_dataset.filter(relation => [user]).count >= 1
      end
    end

    def self.related_space_contains_user?(obj, user, relation)
      if !obj.new? && obj.respond_to?(:space)
        obj.space.send("#{relation}_dataset")[user.id] != nil
      end
    end
  end
end
