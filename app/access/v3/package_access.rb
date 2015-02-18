module VCAP::CloudController
  class PackageModelAccess
    include Allowy::AccessControl

    def read?(package)
      return true if context.roles.admin?

      has_read_scope = SecurityContext.scopes.include?('cloud_controller.read')
      space_guid = AppModel.where(guid: package.app_guid).first.space_guid
      user_visible = Space.user_visible(context.user).where(guid: space_guid).count > 0

      has_read_scope && user_visible
    end

    def create?(_, space)
      return true if context.roles.admin?

      has_write_scope = SecurityContext.scopes.include?('cloud_controller.write')
      is_space_developer = space && space.developers.include?(context.user)
      org_active = space && space.organization.active?

      has_write_scope && is_space_developer && org_active
    end

    def delete?(package, space)
      create?(package, space)
    end

    def upload?(package, space)
      return true if context.roles.admin?
      return false unless FeatureFlag.enabled?('app_bits_upload')
      create?(package, space)
    end
  end
end
