require 'allowy/access_control'

module VCAP::CloudController
  class BaseAccess
    include Allowy::AccessControl

    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)

      @ok_read = (admin_user? || admin_read_only_user? || global_auditor? || object_is_visible_to_user?(object, context.user))
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
      object.class.user_visible(user, false).where(guid: object.guid).any?
    end

    def admin_user?
      return @admin_user if instance_variable_defined?(:@admin_user)

      @admin_user = context.roles.admin?
    end

    def admin_read_only_user?
      return @admin_read_only_user if instance_variable_defined?(:@admin_read_only_user)

      @admin_read_only_user = context.roles.admin_read_only?
    end

    def global_auditor?
      return @global_auditor_user if instance_variable_defined?(:@global_auditor_user)

      @global_auditor_user = context.roles.global_auditor?
    end
  end
end
