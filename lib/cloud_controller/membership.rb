module VCAP::CloudController
  class Membership
    SPACE_DEVELOPER = 'space_developer'.freeze
    SPACE_MANAGER = 'space_manager'.freeze
    SPACE_AUDITOR = 'space_auditor'.freeze
    SPACE_SUPPORTER = 'space_supporter'.freeze
    ORG_USER = 'organization_user'.freeze
    ORG_MANAGER = 'organization_manager'.freeze
    ORG_AUDITOR = 'organization_auditor'.freeze
    ORG_BILLING_MANAGER = 'organization_billing_manager'.freeze

    SPACE_ROLES = %w(space_developer space_manager space_auditor space_supporter).freeze
    ORG_ROLES = %w(organization_manager organization_billing_manager organization_auditor organization_user).freeze

    def initialize(user)
      @user = user
    end

    def has_any_roles?(roles, space_id=nil, org_id=nil)
      if space_id && space_role?(roles)
        return true unless SpaceRole.where(type: space_roles(roles), user_id: @user.id, space_id: space_id).empty?
      end

      if org_id && org_role?(roles)
        return true unless OrganizationRole.where(type: org_roles(roles), user_id: @user.id, organization_id: org_id).empty?
      end

      false
    end

    def org_guids_for_roles(roles)
      org_guids_for_roles_subquery(roles).select_map(:guid)
    end

    def org_guids_for_roles_subquery(roles)
      orgs_for_roles_subquery(roles).select(:guid)
    end

    def orgs_for_roles_subquery(roles)
      org_ids = org_ids_for_org_roles(roles)
      space_ids = space_ids_for_space_roles(roles)
      org_ids_from_space_roles = if space_ids
                                   Space.where(id: space_ids).select(:organization_id)
                                 end
      Organization.where(id: org_ids).or(id: org_ids_from_space_roles).select(:id, :guid)
    end

    def space_guids_for_roles(roles)
      space_guids_for_roles_subquery(roles).select_map(:guid)
    end

    def space_guids_for_roles_subquery(roles)
      spaces_for_roles_subquery(roles).select(:guid)
    end

    def spaces_for_roles_subquery(roles)
      space_ids = space_ids_for_space_roles(roles)
      org_ids = org_ids_for_org_roles(roles)
      Space.where(id: space_ids).or(organization_id: org_ids).select(:id, :guid)
    end

    private

    def space_roles(roles)
      Array(roles) & SPACE_ROLES
    end

    def org_roles(roles)
      Array(roles) & ORG_ROLES
    end

    def space_role?(roles)
      space_roles(roles).any?
    end

    def org_role?(roles)
      org_roles(roles).any?
    end

    def space_ids_for_space_roles(roles)
      if space_role?(roles)
        SpaceRole.where(type: space_roles(roles), user_id: @user.id).select(:space_id)
      end
    end

    def org_ids_for_org_roles(roles)
      if org_role?(roles)
        OrganizationRole.where(type: org_roles(roles), user_id: @user.id).select(:organization_id)
      end
    end
  end
end
