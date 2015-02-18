module VCAP::CloudController
  class DropletModelAccess
    include Allowy::AccessControl

    def read?(droplet, app_model)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = Space.user_visible(context.user).where(guid: app_model.space_guid).count > 0

      has_read_scope && user_visible
    end

    def create?(_, space)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')
      is_space_developer = space && space.developers.include?(context.user)
      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end

    def delete?(droplet, space)
      create?(droplet, space)
    end
  end
end
