module VCAP::CloudController
  class SpaceAccess < BaseAccess
    def create?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user)
    end

    def read_for_update?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      return true if space.organization.managers.include?(context.user)
      space.managers.include?(context.user) && !(params && params.has_key?(:space_quota_definition_guid.to_s))
    end

    def update?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user) || space.managers.include?(context.user)
    end

    def delete?(space)
      create?(space)
    end
  end
end
