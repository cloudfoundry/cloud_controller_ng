module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route, params=nil)
      return true if admin_user?
      return false if route.in_suspended_org?
      FeatureFlag.raise_unless_enabled!('route_creation')
      route.space.developers.include?(context.user)
    end

    def read_for_update?(route, params=nil)
      update?(route, params)
    end

    def update?(route, params=nil)
      return true if admin_user?
      return false if route.in_suspended_org?
      route.space.developers.include?(context.user)
    end

    def delete?(route)
      update?(route)
    end
  end
end
