module VCAP::CloudController
  class RouteMappingAccess < BaseAccess
    def create?(route_mapping, params=nil)
      return true if admin_user?
      return false if route_mapping.route.in_suspended_org?
      route_mapping.route.space.has_developer?(context.user)
    end

    def delete?(route_mapping)
      create?(route_mapping)
    end
  end
end
