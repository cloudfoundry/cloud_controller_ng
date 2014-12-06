module VCAP::CloudController
  class AppModelAccess
    include Allowy::AccessControl

    def read?(app)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = AppModel.user_visible(context.user).where(guid: app.guid).count > 0

      has_read_scope && user_visible
    end

    def create?(desired_app)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')

      space = Space.find(guid: desired_app.space_guid)
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
