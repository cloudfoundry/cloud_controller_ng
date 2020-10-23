module VCAP::CloudController
  class Membership
    SPACE_DEVELOPER     = 0
    SPACE_MANAGER       = 1
    SPACE_AUDITOR       = 2
    ORG_USER            = 3
    ORG_MANAGER         = 4
    ORG_AUDITOR         = 5
    ORG_BILLING_MANAGER = 6

    def initialize(user)
      @user = user
    end

    def has_any_roles?(roles, space_guid=nil, org_guid=nil)
      roles = Array(roles)

      member_guids = member_guids(roles: roles)
      member_guids.include?(space_guid) || member_guids.include?(org_guid)
    end

    def org_guids_for_roles(roles)
      roles = Array(roles)

      roles.map do |role|
        case role
        when ORG_USER
          @user.organizations.map(&:guid)
        when ORG_AUDITOR
          @user.audited_organizations.map(&:guid)
        when ORG_BILLING_MANAGER
          @user.billing_managed_organizations.map(&:guid)
        when ORG_MANAGER
          @user.managed_organizations.map(&:guid)
        end
      end.flatten.compact.uniq
    end

    # rubocop:todo Metrics/CyclomaticComplexity
    def space_guids_for_roles(roles)
      roles = Array(roles)

      roles.map do |role|
        case role
        when SPACE_DEVELOPER
          @user.spaces.map(&:guid)
        when SPACE_MANAGER
          @user.managed_spaces.map(&:guid)
        when SPACE_AUDITOR
          @user.audited_spaces.map(&:guid)
        when ORG_USER
          @user.organizations_dataset.join(
            :spaces, spaces__organization_id: :organizations__id
          ).select(:spaces__guid).map(&:guid)
        when ORG_MANAGER
          @user.managed_organizations_dataset.join(
            :spaces, spaces__organization_id: :organizations__id
          ).select(:spaces__guid).map(&:guid)
        when ORG_BILLING_MANAGER
          @user.billing_managed_organizations_dataset.join(
            :spaces, spaces__organization_id: :organizations__id
          ).select(:spaces__guid).map(&:guid)
        when ORG_AUDITOR
          @user.audited_organizations_dataset.join(
            :spaces, spaces__organization_id: :organizations__id
          ).select(:spaces__guid).map(&:guid)
        end
      end.flatten.compact.uniq
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    # rubocop:todo Metrics/CyclomaticComplexity
    def member_guids(roles: [])
      roles.map do |role|
        case role
        when SPACE_DEVELOPER
          @space_developer ||=
            @user.spaces_dataset.
            association_join(:organization).map(&:guid)
        when SPACE_MANAGER
          @space_manager ||=
            @user.managed_spaces_dataset.
            association_join(:organization).map(&:guid)
        when SPACE_AUDITOR
          @space_auditor ||=
            @user.audited_spaces_dataset.
            association_join(:organization).map(&:guid)
        when ORG_USER
          @org_user ||=
            @user.organizations_dataset.map(&:guid)
        when ORG_MANAGER
          @org_manager ||=
            @user.managed_organizations_dataset.map(&:guid)
        when ORG_AUDITOR
          @org_auditor ||=
            @user.audited_organizations_dataset.map(&:guid)
        when ORG_BILLING_MANAGER
          @org_billing_manager ||=
            @user.billing_managed_organizations_dataset.map(&:guid)
        end
      end.flatten.compact
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
