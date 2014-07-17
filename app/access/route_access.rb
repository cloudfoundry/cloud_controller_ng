module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route)
      return true if admin_user?
      return false if route.in_suspended_org?
      route.space.developers.include?(context.user) ||
        route.space.managers.include?(context.user)
    end

    def update?(route)
      create?(route)
    end

    def delete?(route)
      create?(route)
    end
  end
end
