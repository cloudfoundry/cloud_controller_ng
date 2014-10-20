module VCAP::CloudController
  class AppProcessAccess
    include Allowy::AccessControl

    def read?(process)
      return true if context.roles.admin?
      has_read_scope = VCAP::CloudController::SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = ProcessModel.user_visible(context.user, false).where(:guid => process.guid).count > 0
      has_read_scope && user_visible
    end
  end
end
