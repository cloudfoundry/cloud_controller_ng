module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance, params=nil)
      return true if admin_user?
      FeatureFlag.raise_unless_enabled!('service_instance_creation')
      return false if service_instance.in_suspended_org?
      service_instance.space.has_developer?(context.user) && allowed?(service_instance)
    end

    def read_for_update?(service_instance, params=nil)
      update?(service_instance, params)
    end

    def update?(service_instance, params=nil)
      return true if admin_user?
      return false if service_instance.in_suspended_org?
      service_instance.space.has_developer?(context.user) && allowed?(service_instance)
    end

    def delete?(service_instance)
      return true if admin_user?
      return false if service_instance.in_suspended_org?
      service_instance.space.has_developer?(context.user)
    end

    def read_permissions?(service_instance)
      return true if admin_user?
      service_instance.space.has_developer?(context.user)
    end

    def read_permissions_with_token?(service_instance)
      read_with_token?(service_instance) || has_read_permissions_scope?
    end

    def allowed?(service_instance)
      return true if admin_user?

      case (service_instance.type)
      when 'managed_service_instance'
        ManagedServiceInstanceAccess.new(context).allowed?(service_instance)
      when 'user_provided_service_instance'
        UserProvidedServiceInstanceAccess.new(context).allowed?(service_instance)
      else
        false
      end
    end

    def purge?(_)
      admin_user?
    end

    def purge_with_token?(instance)
      purge?(instance)
    end

    private

    def has_read_permissions_scope?
      VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller_service_permissions.read')
    end
  end

  class UserProvidedServiceInstanceAccess < ServiceInstanceAccess
    def allowed?(service_instance)
      true
    end
  end
end
