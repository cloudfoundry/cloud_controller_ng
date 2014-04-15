module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def create?(service_instance)
      return true if admin_user?
      return false unless has_write_scope?
      return false if service_instance.in_suspended_org?
      service_instance.space.developers.include?(context.user)
    end

    def read?(service_instance)
      return @ok_read if instance_variable_defined?(:@ok_read)
      @ok_read = (admin_user? || (ensure_has_read_scope && object_is_visible_to_user?(service_instance, context.user)))
    end

    def update?(service_instance)
      create?(service_instance)
    end

    def delete?(service_instance)
      create?(service_instance)
    end

    private

    def ensure_has_read_scope
      raise Errors::MissingRequiredScopeError unless VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller.read')
      true
    end
  end

  class ManagedServiceInstanceAccess < ServiceInstanceAccess
  end

  class UserProvidedServiceInstanceAccess < ServiceInstanceAccess
  end
end
