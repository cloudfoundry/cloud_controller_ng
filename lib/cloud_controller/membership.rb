module VCAP::CloudController
  class Membership
    SPACE_DEVELOPER     = 0
    SPACE_MANAGER       = 1
    SPACE_AUDITOR       = 2
    ORG_MEMBER          = 3
    ORG_MANAGER         = 4
    ORG_AUDITOR         = 5
    ORG_BILLING_MANAGER = 6

    def initialize(user)
      @user = user
    end

    def has_any_roles?(roles, space_guid=nil, org_guid=nil)
      roles = [roles] unless roles.is_a?(Array)

      return true if @user.admin?
      member_guids = member_guids(roles: roles)
      member_guids.include?(space_guid) || member_guids.include?(org_guid)
    end

    def admin?
      @user.admin?
    end

    def space_guids
      spaces = @user.spaces + @user.audited_spaces + @user.managed_spaces
      org_guids = @user.managed_organizations.map(&:guid)
      space_guids_from_orgs = Space.join(:organizations, organizations__id: :spaces__organization_id).where(organizations__guid: org_guids).select(:spaces__guid).map(&:guid)

      spaces.map(&:guid) + space_guids_from_orgs
    end

    private

    def member_guids(roles: [])
      roles.map do |role|
        case role
        when SPACE_DEVELOPER
          @space_developer ||=
            @user.spaces_dataset.
              association_join(:organization).
              where(organization__status: 'active').map(&:guid)
        when SPACE_MANAGER
          @space_manager ||=
            @user.managed_spaces_dataset.
              association_join(:organization).
              where(organization__status: 'active').map(&:guid)
        when SPACE_AUDITOR
          @space_auditor ||=
            @user.audited_spaces_dataset.
              association_join(:organization).
              where(organization__status: 'active').map(&:guid)
        when ORG_MEMBER
          @org_member ||=
            @user.organizations_dataset.
              where(status: 'active').map(&:guid)
        when ORG_MANAGER
          @org_manager ||=
            @user.managed_organizations_dataset.
              where(status: 'active').map(&:guid)
        when ORG_AUDITOR
          @org_auditor ||=
            @user.audited_organizations_dataset.
              where(status: 'active').map(&:guid)
        when ORG_BILLING_MANAGER
          @org_billing_manager ||=
            @user.billing_managed_organizations_dataset.
              where(status: 'active').map(&:guid)
        end
      end.flatten.compact
    end
  end
end
