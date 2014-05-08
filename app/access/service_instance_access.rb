module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance)
      return true if admin_user?
      return false if service_instance.in_suspended_org?
      service_instance.space.developers.include?(context.user)
    end

    def update?(service_instance)
      create?(service_instance)
    end

    def delete?(service_instance)
      create?(service_instance)
    end

    def read_permissions?(service_instance)
      read?(service_instance)
    end

    def read_permissions_with_token?(service_instance)
      read_with_token?(service_instance) || has_read_permissions_scope?
    end

    private

    def has_read_permissions_scope?
      VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller_service_permissions.read')
    end
  end

  class ManagedServiceInstanceAccess < ServiceInstanceAccess
  end

  class UserProvidedServiceInstanceAccess < ServiceInstanceAccess
  end
end
