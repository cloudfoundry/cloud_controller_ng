module VCAP::CloudController
  class RouteAccess < BaseAccess
    def create?(route, params=nil)
      return true if context.queryer.can_write_globally?
      return false if route.in_suspended_org?
      return false if route.wildcard_host? && route.domain.shared?
      FeatureFlag.raise_unless_enabled!(:route_creation)
      context.queryer.can_write_to_space?(route.space.guid)
    end

    def read?(route)
      context.queryer.can_read_route?(route.space.guid, route.space.organization.guid)
    end

    def read_for_update?(route, params=nil)
      can_write_to_route(route)
    end

    def update?(route, params=nil)
      can_write_to_route(route)
    end

    def delete?(route)
      can_write_to_route(route)
    end

    def reserved?(_)
      logged_in?
    end

    def reserved_with_token?(_)
      admin_user? || has_read_scope?
    end

    private

    def can_write_to_route(route)
      return true if context.queryer.can_write_globally?
      return false if route.in_suspended_org?
      return false if route.wildcard_host? && route.domain.shared?
      context.queryer.can_write_to_space?(route.space.guid)
    end
  end
end
