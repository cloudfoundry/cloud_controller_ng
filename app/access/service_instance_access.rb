module VCAP::CloudController
  class ServiceInstanceAccess < BaseAccess
    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)

      @ok_read = (admin_user? || admin_read_only_user? || global_auditor? || object_is_visible_to_user?(object, context.user))
    end

    def can_remove_related_object?(object, params=nil)
      read_for_update?(object, params)
    end

    def read_related_object_for_update?(object, params=nil)
      read_for_update?(object, params)
    end

    def index?(object_class, params=nil)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    # These methods should be called first to determine if the user's token has the appropriate scope for the operation

    def read_with_token?(_)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def create_with_token?(_)
      admin_user? || has_write_scope?
    end

    def read_for_update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def can_remove_related_object_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def read_related_object_for_update_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def delete_with_token?(_)
      admin_user? || has_write_scope?
    end

    def index_with_token?(_)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    def create?(service_instance, params=nil)
      return true if admin_user?

      FeatureFlag.raise_unless_enabled!(:service_instance_creation)
      return false if service_instance.in_suspended_org?

      service_instance.space&.has_developer?(context.user) && allowed?(service_instance)
    end

    def read_for_update?(service_instance, params=nil)
      return true if admin_user?
      return false if service_instance.in_suspended_org?

      service_instance.space&.has_developer?(context.user)
    end

    def update?(service_instance, params=nil)
      read_for_update?(service_instance, params) && allowed?(service_instance)
    end

    def delete?(service_instance)
      return true if admin_user?
      return false if service_instance.in_suspended_org?

      service_instance.space&.has_developer?(context.user)
    end

    def manage_permissions?(service_instance)
      return true if admin_user?

      service_instance.space&.has_developer?(context.user)
    end

    def manage_permissions_with_token?(service_instance)
      read_with_token?(service_instance) || has_read_permissions_scope?
    end

    def read_permissions?(service_instance)
      admin_user? || admin_read_only_user? || object_is_visible_to_user?(service_instance, context.user)
    end

    def read_permissions_with_token?(service_instance)
      read_with_token?(service_instance) || has_read_permissions_scope?
    end

    def read_env?(service_instance)
      return true if admin_user? || admin_read_only_user?

      service_instance.space&.has_developer?(context.user)
    end

    def read_env_with_token?(service_instance)
      read_with_token?(service_instance)
    end

    def allowed?(service_instance)
      return true if admin_user?

      case service_instance.type
      when 'managed_service_instance'
        ManagedServiceInstanceAccess.new(context).allowed?(service_instance)
      when 'user_provided_service_instance'
        UserProvidedServiceInstanceAccess.new(context).allowed?(service_instance)
      else
        false
      end
    end

    def purge?(service_instance)
      admin_user? ||
        (service_instance.space&.has_developer?(context.user) &&
         service_instance.service_broker.space_scoped?)
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
