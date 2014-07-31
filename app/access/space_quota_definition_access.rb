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

    def read?(space_quota_definition)
      context.roles.admin? || (
        !context.user.nil? && (
          (context.user.managed_organizations.include? space_quota_definition.organization) ||
          ((context.user.managed_spaces & space_quota_definition.spaces).length > 0) ||
          ((context.user.audited_spaces & space_quota_definition.spaces).length > 0) ||
          ((context.user.spaces & space_quota_definition.spaces).length > 0)
        )
      )
    end
  end
end
