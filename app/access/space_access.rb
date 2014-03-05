module VCAP::CloudController
  class SpaceAccess < BaseAccess
    def create?(space)
      return super if super
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user)
    end

    def update?(space)
      return super if super
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user) || space.managers.include?(context.user)
    end

    def delete?(space)
      create?(space)
    end
  end
end
