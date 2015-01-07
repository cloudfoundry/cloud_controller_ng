module VCAP::CloudController
  class PackageModelAccess
    include Allowy::AccessControl

    def read?(package)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = AppModel.user_visible(context.user).where(guid: package.app_guid).count > 0

      has_read_scope && user_visible
    end

    def create?(desired_package)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')

      app = AppModel.find(guid: desired_package.app_guid)
      space = Space.find(guid: app.space_guid)

      is_space_developer = space && space.developers.include?(context.user)

      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end

    def delete?(app)
      create?(app)
    end

    def update?(app)
      create?(app)
    end
  end
end
