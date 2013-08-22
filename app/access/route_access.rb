module VCAP::CloudController::Models
  class RouteAccess < BaseAccess
    def read?(route)
      super ||
        route.space.organization.managers.include?(context.user) ||
        route.space.organization.auditors.include?(context.user) ||
        [:managers, :developers, :auditors].any? do |type|
          route.space.send(type).include?(context.user)
        end
    end

    def create?(route)
      super ||
        route.space.organization.managers.include?(context.user) ||
        [:managers, :developers].any? do |type|
          route.space.send(type).include?(context.user)
        end
    end

    alias :update? :create?
    alias :delete? :create?
  end
end