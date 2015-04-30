module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route, params=nil)
      return true if admin_user?
      return false if route.in_suspended_org?
      return false if route.host == '*' && route.domain.shared?
      FeatureFlag.raise_unless_enabled!('route_creation')
      route.space.developers.include?(context.user)
    end

    def read_for_update?(route, params=nil)
      update?(route, params)
    end

    def update?(route, params=nil)
      return true if admin_user?
      return false if route.in_suspended_org?
      return false if route.host == '*' && route.domain.shared?
      route.space.developers.include?(context.user)
    end

    def delete?(route)
      update?(route)
    end

    def reserved?(_)
      logged_in?
    end

    def reserved_with_token?(_)
      admin_user? || has_read_scope?
    end
  end
end
