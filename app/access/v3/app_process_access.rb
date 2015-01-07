module VCAP::CloudController
  class AppProcessAccess
    include Allowy::AccessControl

    def create?(desired_process, space)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')

      is_space_developer = space && space.developers.include?(context.user)

      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end

    def read?(process)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = App.user_visible(context.user, false).where(guid: process.guid).count > 0

      has_read_scope && user_visible
    end

    def delete?(process, space)
      create?(process, space)
    end

    def update?(process, space)
      create?(process, space)
    end
  end
end
