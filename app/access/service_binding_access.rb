module VCAP::CloudController
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding, params=nil)
      return true if admin_user?
      return false if service_binding.in_suspended_org?
      service_binding.app.space.developers.include?(context.user)
    end

    def delete?(service_binding)
      create?(service_binding)
    end
  end
end
