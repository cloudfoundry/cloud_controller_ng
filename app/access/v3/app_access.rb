module VCAP::CloudController
  class AppModelAccess
    include Allowy::AccessControl

    def read?(app_model)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      user_visible = AppModel.user_visible(context.user).where(guid: app_model.guid).count > 0

      has_read_scope && user_visible
    end

    def create?(app_model)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')

      space = Space.find(guid: app_model.space_guid)
      is_space_developer = space && space.developers.include?(context.user)

      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end

    def delete?(app_model)
      create?(app_model)
    end
  end
end
