module VCAP::CloudController
  class ProcessModelAccess < BaseAccess
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

    def create?(app, params=nil)
      return true if admin_user?
      return false if app.in_suspended_org?

      app.space&.has_developer?(context.user)
    end

    def read_for_update?(app, params=nil)
      return true if admin_user?
      return false unless create?(app, params)
      return true if params.nil?

      if %w(instances memory disk_quota).any? { |k| params.key?(k) && params[k] != app.send(k.to_sym) }
        FeatureFlag.raise_unless_enabled!(:app_scaling)
      end

      true
    end

    def update?(app, params=nil)
      create?(app, params)
    end

    def delete?(app)
      create?(app)
    end

    def read_env?(app)
      return true if admin_user? || admin_read_only_user?

      app.space&.has_developer?(context.user)
    end

    def read_env_with_token?(app)
      read_with_token?(app)
    end

    def read_permissions?(app)
      return true if admin_user? || admin_read_only_user?

      app.space&.has_developer?(context.user)
    end

    def read_permissions_with_token?(app)
      read_with_token?(app) || has_user_scope?
    end

    def upload?(app)
      FeatureFlag.raise_unless_enabled!(:app_bits_upload)
      update?(app)
    end

    def upload_with_token?(_)
      admin_user? || has_write_scope?
    end

    private

    def has_user_scope?
      VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller.user')
    end
  end
end
