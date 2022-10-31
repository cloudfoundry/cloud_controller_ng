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

    def role_applies?(roles, space_id=nil, org_id=nil)
      role_applies_to_space?(roles, space_id) || role_applies_to_org?(roles, org_id)
    end

    def authorized_org_guids(roles)
      authorized_org_guids_subquery(roles).select_map(:guid)
    end

    def authorized_org_guids_subquery(roles)
      authorized_orgs_subquery(roles).select(:guid)
    end

    def authorized_orgs_subquery(roles)
      space_ids = member_space_ids(roles)
      org_ids_from_space_roles = Space.where(id: space_ids).select(:organization_id) if space_ids

      if org_ids_from_space_roles
        Organization.where(id: member_org_ids(roles)).or(id: org_ids_from_space_roles)
      else
        Organization.where(id: member_org_ids(roles))
      end
    end

    def authorized_space_guids(roles)
      authorized_space_guids_subquery(roles).select_map(:guid)
    end

    def authorized_space_guids_subquery(roles)
      authorized_spaces_subquery(roles).select(:guid)
    end

    def authorized_spaces_subquery(roles)
      org_ids = member_org_ids(roles)
      if org_ids
        Space.where(id: member_space_ids(roles)).or(organization_id: org_ids).select(:id, :guid)
      else
        Space.where(id: member_space_ids(roles)).select(:id, :guid)
      end
    end

    def member_space_ids(roles)
      space_role_models(roles).reduce do |query, role|
        query.union(role.dataset.select(:space_id).where(user_id: @user.id), from_self: false)
      end&.select_map(:space_id)
    end

    def member_org_ids(roles)
      org_role_models(roles).reduce do |query, role|
        query.union(role.dataset.select(:organization_id).where(user_id: @user.id), from_self: false)
      end&.select_map(:organization_id)
    end

    private

    def role_applies_to_space?(roles, space_id)
      return false unless space_id && space_role_sufficient?(roles)

      member_space_ids(roles).include?(space_id)
    end

    def role_applies_to_org?(roles, org_id)
      return false unless org_id && org_role_sufficient?(roles)

      member_org_ids(roles).include?(org_id)
    end

    def roles_filter(roles, filter)
      Array(roles).intersection(filter)
    end

    def space_role_sufficient?(roles)
      roles_filter(roles, SPACE_ROLES).any?
    end

    def org_role_sufficient?(roles)
      roles_filter(roles, ORG_ROLES).any?
    end

    def space_role_models(roles)
      roles_filter(roles, SPACE_ROLES).map do |space_role|
        case space_role
        when SPACE_DEVELOPER
          SpaceDeveloper
        when SPACE_MANAGER
          SpaceManager
        when SPACE_AUDITOR
          SpaceAuditor
        when SPACE_SUPPORTER
          SpaceSupporter
        end
      end.compact
    end

    def org_role_models(roles)
      roles_filter(roles, ORG_ROLES).map do |org_role|
        case org_role
        when ORG_MANAGER
          OrganizationManager
        when ORG_AUDITOR
          OrganizationAuditor
        when ORG_BILLING_MANAGER
          OrganizationBillingManager
        when ORG_USER
          OrganizationUser
        end
      end.compact
    end
  end
end
