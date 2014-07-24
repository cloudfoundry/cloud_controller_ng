module VCAP::CloudController
  class SpaceQuotaDefinitionAccess < BaseAccess
    def create?(space_quota_definition)
      return true if admin_user?
      return false if space_quota_definition.organization.suspended?
      space_quota_definition.organization.managers.include?(context.user)
    end

    def update?(space_quota_definition)
      create?(space_quota_definition)
    end

    def delete?(space_quota_definition)
      create?(space_quota_definition)
    end
  end
end
