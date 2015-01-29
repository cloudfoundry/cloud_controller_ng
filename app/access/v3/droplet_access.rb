module VCAP::CloudController
  class DropletModelAccess
    include Allowy::AccessControl

    def create?(_, space)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')
      is_space_developer = space && space.developers.include?(context.user)
      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end
  end
end
