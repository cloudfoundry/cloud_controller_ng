module VCAP::CloudController
  class ServiceKeyAccess < BaseAccess
    def create?(service_key, params=nil)
      return true if admin_user?
      return false if service_key.in_suspended_org?
      service_key.service_instance.space.developers.include?(context.user)
    end

    def delete?(service_key)
      create?(service_key)
    end
  end
end
