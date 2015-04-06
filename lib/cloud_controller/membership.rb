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

    private

    def member_guids(roles: [])
      roles.map do |role|
        case role
        when SPACE_DEVELOPER
          @user.spaces.map(&:guid)
        when SPACE_MANAGER
          @user.managed_spaces.map(&:guid)
        when SPACE_AUDITOR
          @user.audited_spaces.map(&:guid)
        when ORG_MEMBER
          @user.organizations.map(&:guid)
        when ORG_MANAGER
          @user.managed_organizations.map(&:guid)
        when ORG_AUDITOR
          @user.audited_organizations.map(&:guid)
        when ORG_BILLING_MANAGER
          @user.billing_managed_organizations.map(&:guid)
        end
      end.flatten.compact
    end
  end
end
