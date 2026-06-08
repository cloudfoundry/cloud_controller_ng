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

    SPACE_ROLES = %w[space_developer space_manager space_auditor space_supporter].freeze
    ORG_ROLES = %w[organization_manager organization_billing_manager organization_auditor organization_user].freeze

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
      Organization.where(id: authorized_org_ids_subquery(roles))
    end

    def authorized_space_guids(roles)
      authorized_space_guids_subquery(roles).select_map(:guid)
    end

    def authorized_space_guids_subquery(roles)
      authorized_spaces_subquery(roles).select(:guid)
    end

    def authorized_spaces_subquery(roles)
      Space.where(id: authorized_space_ids_subquery(roles)).select(:id, :guid)
    end

    # Like authorized_spaces_subquery but returns a flat id-only UNION (no Space.where wrapper).
    # Use when the caller filters by a raw space_id FK column to avoid an extra subplan over `spaces`.
    def authorized_space_ids_subquery(roles)
      space_ids_query = member_space_ids(roles)
      org_ids_query   = member_org_ids(roles)

      space_ids_via_orgs = Space.where(organization_id: org_ids_query).select(:id) if org_ids_query

      if space_ids_query && space_ids_via_orgs
        space_ids_query.union(space_ids_via_orgs, from_self: false)
      else
        space_ids_query || space_ids_via_orgs
      end
    end

    # Like authorized_orgs_subquery but returns a flat id-only UNION (no Organization.where wrapper).
    # Use when the caller filters by a raw organization_id FK column.
    def authorized_org_ids_subquery(roles)
      space_ids_query = member_space_ids(roles)
      org_ids_query   = member_org_ids(roles)

      org_ids_via_space_roles = Space.where(id: space_ids_query).select(:organization_id) if space_ids_query

      if org_ids_query && org_ids_via_space_roles
        org_ids_query.union(org_ids_via_space_roles, from_self: false)
      else
        org_ids_query || org_ids_via_space_roles
      end
    end

    def member_space_ids(roles, extra_filters={})
      space_role_subqueries(roles, extra_filters).reduce do |query, subquery|
        query.union(subquery, from_self: false)
      end&.select(:space_id)
    end

    def member_org_ids(roles, extra_filters={})
      org_role_subqueries(roles, extra_filters).reduce do |query, subquery|
        query.union(subquery, from_self: false)
      end&.select(:organization_id)
    end

    def visible_user_ids_in_orgs(org_roles)
      org_ids = member_org_ids(org_roles)
      return nil unless org_ids

      OrganizationUser.where(organization_id: org_ids).select(:user_id).
        union(OrganizationManager.where(organization_id: org_ids).select(:user_id), from_self: false).
        union(OrganizationAuditor.where(organization_id: org_ids).select(:user_id), from_self: false).
        union(OrganizationBillingManager.where(organization_id: org_ids).select(:user_id), from_self: false).
        select(:user_id)
    end

    private

    def role_applies_to_space?(roles, space_id)
      return false unless space_id && contains_space_role?(roles)

      member_space_ids(roles, space_id:).any?
    end

    def role_applies_to_org?(roles, org_id)
      return false unless org_id && contains_org_role?(roles)

      member_org_ids(roles, organization_id: org_id).any?
    end

    def roles_filter(roles, filter)
      Array(roles).intersection(filter)
    end

    def contains_space_role?(roles)
      roles_filter(roles, SPACE_ROLES).any?
    end

    def contains_org_role?(roles)
      roles_filter(roles, ORG_ROLES).any?
    end

    def space_role_subqueries(roles, extra_filters={})
      roles_filter(roles, SPACE_ROLES).map do |space_role|
        case space_role
        when SPACE_DEVELOPER
          SpaceDeveloper.where(extra_filters.merge(user_id: @user.id)).select(:space_id)
        when SPACE_MANAGER
          SpaceManager.where(extra_filters.merge(user_id: @user.id)).select(:space_id)
        when SPACE_AUDITOR
          SpaceAuditor.where(extra_filters.merge(user_id: @user.id)).select(:space_id)
        when SPACE_SUPPORTER
          SpaceSupporter.where(extra_filters.merge(user_id: @user.id)).select(:space_id)
        end
      end.compact
    end

    def org_role_subqueries(roles, extra_filters={})
      roles_filter(roles, ORG_ROLES).map do |org_role|
        case org_role
        when ORG_MANAGER
          OrganizationManager.where(extra_filters.merge(user_id: @user.id)).select(:organization_id)
        when ORG_AUDITOR
          OrganizationAuditor.where(extra_filters.merge(user_id: @user.id)).select(:organization_id)
        when ORG_BILLING_MANAGER
          OrganizationBillingManager.where(extra_filters.merge(user_id: @user.id)).select(:organization_id)
        when ORG_USER
          OrganizationUser.where(extra_filters.merge(user_id: @user.id)).select(:organization_id)
        end
      end.compact
    end
  end
end
