module VCAP::CloudController::Models
  class RouteAccess < BaseAccess
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
