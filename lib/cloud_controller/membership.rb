module VCAP::CloudController
  class Membership
    SPACE_DEVELOPER = "space_developer"
    SPACE_MANAGER = "space_manager"
    SPACE_AUDITOR = "space_auditor"
    SPACE_APPLICATION_SUPPORTER = "space_application_supporter"
    ORG_USER = "organization_user"
    ORG_MANAGER = "organization_manager"
    ORG_AUDITOR = "organization_auditor"
    ORG_BILLING_MANAGER = "organization_billing_manager"

    SPACE_ROLES = %w(space_developer space_manager space_auditor)
    ORG_ROLES = %w(organization_manager organization_billing_manager organization_auditor organization_user)

    def initialize(user)
      @user = user
    end

    def has_any_roles?(roles, space_guid=nil, org_guid=nil)
      roles = [roles] unless roles.is_a?(Array)

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
      roles = [roles] unless roles.is_a?(Array)
      space_roles = roles && SPACE_ROLES
      org_roles = roles && ORG_ROLES

      # space_role_datset = Role.where(type: space_roles, user_id: @user.id).map(&:space_guid).uniq
      # org_role_based_space_guids =  Role.where(type: org_roles, user_id: @user.id).map(&:organization_guid)
      # #org_role_dataset = Organization.where() --> find a way to get the spaces guids through their belonging relationship to orgs
      #
      # Role.where(type: roles)
      # space_roles = roles && SPACE_ROLES
      # org_roles = roles && ORG_ROLES
      #
      # space_role_datset = Role.where(type: space_roles, user_id: @user.id).map(&:space_guid).uniq
      # org_role_based_space_guids =  Role.where(type: org_roles, user_id: @user.id).map(&:organization_guid)
      # #org_role_dataset = Organization.where() --> find a way to get the spaces guids through their belonging relationship to orgs
      #
      # Role.where(type: roles)

      space_roles = roles && SPACE_ROLES
      org_roles = roles && ORG_ROLES

      # table of space roles with _ids_ of spaces that user can see
      space_role_dataset = Role.where(type: space_roles, user_id: @user.id)
      # table of _spaces_ that the usr can see
      space_dataset = Space.join(space_role_dataset, space_id: :id).distinct.qualify(:spaces)
      # ^ Instead of -> Space.where(id: space_role_dataset.map(&:space_id)) OR  space_role_dataset.join(:spaces, id: :space_id).distinct.qualify(:spaces)

      # table of org roles with _ids_ of orgs that the user can see
      org_role_dataset = Role.where(type: org_roles, user_id: @user.id)
      # Based on the org roles that the current user has, what spaces can they see?
      space_dataset_for_org_roles = Space.join(org_role_dataset, organization_id: :organization_id).distinct.qualify(:spaces)
      # ^ Instead of Space.where(organization_id: org_role_dataset.map(&:organization_id))

      space_guids_user_can_see = space_dataset_for_org_roles.union(space_dataset)

      # Space.join(:space_role_datset, space_id: :id).where(id: org_role_dataset.map(&:id)).map(&:guid)
      # organizations.id ON spaces.organization_id => space.guids
      #Space.join(:organizations, id: :organization_id).where(id: org_role_dataset.map(&:id)).map(&:guid)

      Role.where(type: roles)

      roles.map do |role|
        case role
        when SPACE_DEVELOPER
          @user.spaces.map(&:guid)
        when SPACE_MANAGER
          @user.managed_spaces.map(&:guid)
        when SPACE_AUDITOR
          @user.audited_spaces.map(&:guid)
        when SPACE_APPLICATION_SUPPORTER
          @user.application_supported_spaces.map(&:guid)
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

      space_guids_user_can_see.map(&:guid)
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
