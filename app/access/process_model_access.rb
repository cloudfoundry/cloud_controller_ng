module VCAP::CloudController
  class ProcessModelAccess < BaseAccess
    def create?(app, params=nil)
      return true if admin_user?
      return false if app.in_suspended_org?
      app.space.has_developer?(context.user)
    end

    def read_for_update?(app, params=nil)
      return true if admin_user?
      return false unless create?(app, params)
      return true if params.nil?

      if %w(instances memory disk_quota).any? { |k| params.key?(k) && params[k] != app.send(k.to_sym) }
        FeatureFlag.raise_unless_enabled!(:app_scaling)
      end

      if !Config.config.get(:users_can_select_backend) && params.key?('diego') && params['diego'] != app.diego
        raise CloudController::Errors::ApiError.new_from_details('BackendSelectionNotAuthorized')
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
      app.space.has_developer?(context.user)
    end

    def read_env_with_token?(app)
      read_with_token?(app)
    end

    def read_permissions?(app)
      return true if admin_user? || admin_read_only_user?
      app.space.has_developer?(context.user)
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
