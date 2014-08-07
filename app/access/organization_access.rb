module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def create?(org)
      return true if admin_user?
      FeatureFlag.enabled?('user_org_creation')
    end

    def update?(org)
      return true if admin_user?
      org.managers.include?(context.user) && org.active?
    end
  end
end
