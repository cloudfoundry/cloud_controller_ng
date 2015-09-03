module VCAP::CloudController
  class RouteBindingAccess < BaseAccess
    def create?(service_binding, params=nil)
      return true if admin_user?
      return false if service_binding.in_suspended_org?
      service_binding.space.has_developer?(context.user)
    end

    def delete?(service_binding)
      create?(service_binding)
    end
  end
end
