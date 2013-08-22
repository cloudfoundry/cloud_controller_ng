module VCAP::CloudController::Models
  class SpaceAccess < BaseAccess
    def create?(space)
      super || space.organization.managers.include?(context.user)
    end

    def read?(space)
      super || space.organization.managers.include?(context.user) ||
        [:managers, :developers, :auditors].any? do |type|
          space.send(type).include?(context.user)
        end
    end

    def update?(space)
      super || space.organization.managers.include?(context.user) ||
        space.managers.include?(context.user)
    end

    alias :delete? :create?
  end
end