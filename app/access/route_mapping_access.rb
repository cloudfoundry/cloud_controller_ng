module VCAP::CloudController
  class RouteMappingAccess < BaseAccess
    def create?(route_mapping, params=nil)
      return true if admin_user?
      return false if route_mapping.route.in_suspended_org?
      route_mapping.route.space.has_developer?(context.user)
    end

    def read_for_update?(route_mapping, params=nil)
      create?(route_mapping)
    end

    def update?(route_mapping, params=nil)
      read_for_update?(route_mapping, params)
    end

    def delete?(route_mapping)
      create?(route_mapping)
    end
  end
end
