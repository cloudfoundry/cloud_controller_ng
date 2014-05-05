module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route)
      return true if admin_user?
      return false if route.in_suspended_org?
      route.space.organization.managers.include?(context.user) ||
        [:managers, :developers].any? do |type|
          route.space.send(type).include?(context.user)
        end
    end

    def update?(route)
      create?(route)
    end

    def delete?(route)
      create?(route)
    end
  end
end
