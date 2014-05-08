module VCAP::CloudController
  class BaseAccess
    include Allowy::AccessControl

    # Only if the token has the appropriate scope, use these methods to check if the user is authorized to access the resource

    def create?(object)
      admin_user?
    end

    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)
      @ok_read = (admin_user? || object_is_visible_to_user?(object, context.user))
    end

    def update?(object)
      admin_user?
    end

    def delete?(object)
      admin_user?
    end

    def index?(object_class)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    # These methods should be called first to determine if the user's token has the appropriate scope for the operation

    def read_with_token?(_)
      admin_user? || has_read_scope?
    end

    def create_with_token?(_)
      admin_user? || has_write_scope?
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

    private

    def logged_in?
      !context.user.nil? || context.roles.present?
    end

    def has_write_scope?
      VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller.write')
    end

    def has_read_scope?
      VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller.read')
    end

    def object_is_visible_to_user?(object, user)
      object.class.user_visible(user, false).where(:guid => object.guid).count > 0
    end

    def admin_user?
      return @admin_user if instance_variable_defined?(:@admin_user)
      @admin_user = context.roles.admin?
    end
  end
end
