module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def create?(org, params=nil)
      return true if admin_user?
      FeatureFlag.enabled?('user_org_creation')
    end

    def read_for_update?(org, params=nil)
      return true if admin_user?
      return false unless org.active?
      return false unless org.managers.include?(context.user)

      if params
        return false if params.key?(:quota_definition_guid.to_s) || params.key?(:billing_enabled.to_s)
      end

      true
    end

    def update?(org, params=nil)
      return true if admin_user?
      return false unless org.active?
      org.managers.include?(context.user)
    end
  end
end
