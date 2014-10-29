module VCAP::CloudController
  class AppModelAccess
    include Allowy::AccessControl

    def read?(app_model)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = AppModel.user_visible(context.user, false).where(guid: app_model.guid).count > 0

      has_read_scope && user_visible
    end
  end
end
