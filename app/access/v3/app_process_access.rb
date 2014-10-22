module VCAP::CloudController
  class AppProcessAccess
    include Allowy::AccessControl

    def create?(desired_process)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')

      space = Space.find(guid: desired_process.space_guid)
      is_space_developer = space && space.developers.include?(context.user)

      org_suspended = space && space.organization.suspended?

      has_write_scope && is_space_developer && !org_suspended
    end

    def read?(process)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = ProcessModel.user_visible(context.user, false).where(:guid => process.guid).count > 0

      has_read_scope && user_visible
    end
  end
end
