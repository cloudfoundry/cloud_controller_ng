module VCAP::CloudController
  class SpaceAccess < BaseAccess
    def create?(space)
      super || space.organization.managers.include?(context.user)
    end

    def update?(space)
      super || space.organization.managers.include?(context.user) ||
        space.managers.include?(context.user)
    end

    alias_method :delete?, :create?
  end
end
