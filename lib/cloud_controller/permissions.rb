class VCAP::CloudController::Permissions
  ROLES_FOR_ORG_READING ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR,
    VCAP::CloudController::Membership::ORG_USER,
    VCAP::CloudController::Membership::ORG_BILLING_MANAGER
  ].freeze

  ROLES_FOR_ORG_CONTENT_READING = [
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ROLES_FOR_ORG_WRITING = [
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ROLES_FOR_SPACE_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  ROLES_FOR_DROPLET_DOWLOAD ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ORG_ROLES_FOR_READING_DOMAINS_FROM_ORGS ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR
  ].freeze

  SPACE_ROLES ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  SPACE_ROLES_FOR_EVENTS ||= [
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  ROLES_FOR_SPACE_SECRETS_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER
  ].freeze

  ROLES_FOR_SPACE_SERVICES_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  ROLES_FOR_ROUTE_READING ||= ROLES_FOR_SPACE_READING + [
    VCAP::CloudController::Membership::ORG_AUDITOR
  ].freeze

  ROLES_FOR_SPACE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER
  ].freeze

  ROLES_FOR_APP_MANAGING ||= (ROLES_FOR_SPACE_WRITING + [
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ]).freeze

  ROLES_FOR_SPACE_UPDATING ||= [
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ROLES_FOR_ROUTE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER
  ].freeze

  ROLES_FOR_APP_ENVIRONMENT_VARIABLES_READING ||= (ROLES_FOR_SPACE_SECRETS_READING + [
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ]).freeze

  def initialize(user)
    @user = user
  end

  def can_read_globally?
    roles.admin? || roles.admin_read_only? || roles.global_auditor?
  end

  def can_read_secrets_globally?
    roles.admin? || roles.admin_read_only?
  end

  def can_write_globally?
    roles.admin?
  end

  def is_org_manager?
    membership.authorized_orgs_subquery(VCAP::CloudController::Membership::ORG_MANAGER).any?
  end

  def readable_org_guids
    readable_org_guids_query.select_map(:guid)
  end

  def readable_org_guids_query
    raise 'must not be called for users that can read globally' if can_read_globally?

    membership.authorized_org_guids_subquery(ROLES_FOR_ORG_READING)
  end

  def can_delete_buildpack_cache?(space_id)
    roles.admin? || membership.role_applies?(ROLES_FOR_APP_MANAGING, space_id)
  end

  def readable_orgs_query
    if can_read_globally?
      VCAP::CloudController::Organization.select(:id, :guid)
    else
      membership.authorized_orgs_subquery(ROLES_FOR_ORG_READING)
    end
  end

  def readable_org_guids_for_domains_query
    if can_read_globally?
      VCAP::CloudController::Organization.select(:guid)
    else
      membership.authorized_org_guids_subquery(ORG_ROLES_FOR_READING_DOMAINS_FROM_ORGS + SPACE_ROLES)
    end
  end

  def can_read_from_org?(org_id)
    can_read_globally? || membership.role_applies?(ROLES_FOR_ORG_READING, nil, org_id)
  end

  def can_write_to_active_org?(org_id)
    return true if can_write_globally?

    membership.role_applies?(ROLES_FOR_ORG_WRITING, nil, org_id)
  end

  def is_org_active?(org_id)
    return true if can_write_globally? # admins can modify suspended orgs

    !VCAP::CloudController::Organization.
      where(id: org_id, status: VCAP::CloudController::Organization::ACTIVE).
      empty?
  end

  def is_space_active?(space_id)
    return true if can_write_globally? # admins can modify suspended orgs

    !VCAP::CloudController::Organization.
      join(:spaces, organization_id: :id).
      where(spaces__id: space_id, organizations__status: VCAP::CloudController::Organization::ACTIVE).
      empty?
  end

  def is_space_deleting?(space_id)
    space = VCAP::CloudController::Space.where(id: space_id).first
    return false unless space

    space.deleting? || space.organization&.status == VCAP::CloudController::Organization::DELETING
  end

  def is_org_deleting?(org_id)
    org = VCAP::CloudController::Organization.where(id: org_id).first
    return false unless org

    org.status == VCAP::CloudController::Organization::DELETING
  end

  def readable_space_guids
    readable_space_guids_query.select_map(:guid)
  end

  def readable_spaces_query
    raise 'must not be called for users that can read globally' if can_read_globally?

    membership.authorized_spaces_subquery(ROLES_FOR_SPACE_READING)
  end

  def readable_space_guids_query
    raise 'must not be called for users that can read globally' if can_read_globally?

    membership.authorized_space_guids_subquery(ROLES_FOR_SPACE_READING)
  end

  def can_read_from_space?(space_id, org_id)
    can_read_globally? || membership.role_applies?(ROLES_FOR_SPACE_READING, space_id, org_id)
  end

  def can_read_from_space_as_space_member?(space_id)
    can_read_globally? || membership.role_applies?(SPACE_ROLES, space_id)
  end

  def can_download_droplet?(space_id, org_id)
    can_read_globally? || membership.role_applies?(ROLES_FOR_DROPLET_DOWLOAD, space_id, org_id)
  end

  def can_read_secrets_in_space?(space_id, org_id)
    can_read_secrets_globally? ||
      membership.role_applies?(ROLES_FOR_SPACE_SECRETS_READING, space_id, org_id)
  end

  def can_read_services_in_space?(space_id, org_id)
    can_read_globally? || membership.role_applies?(ROLES_FOR_SPACE_SERVICES_READING, space_id, org_id)
  end

  def can_write_to_active_space?(space_id)
    return true if can_write_globally?

    membership.role_applies?(ROLES_FOR_SPACE_WRITING, space_id)
  end

  def can_manage_apps_in_active_space?(space_id)
    return true if can_write_globally?

    membership.role_applies?(ROLES_FOR_APP_MANAGING, space_id)
  end

  def can_update_active_space?(space_id, org_id)
    return true if can_write_globally?

    membership.role_applies?(ROLES_FOR_SPACE_UPDATING, space_id, org_id)
  end

  def can_read_from_isolation_segment?(isolation_segment)
    can_read_globally? || readable_org_guids_query.where(isolation_segment_models: isolation_segment).any?
  end

  def readable_services_space_guids
    if can_read_secrets_globally?
      VCAP::CloudController::Space.select_map(:guid)
    else
      membership.authorized_space_guids(ROLES_FOR_SPACE_SERVICES_READING)
    end
  end

  def readable_space_scoped_spaces
    readable_space_scoped_spaces_query.all
  end

  def readable_space_scoped_spaces_query
    if can_read_globally?
      VCAP::CloudController::Space.select(:id, :guid)
    else
      membership.authorized_spaces_subquery(SPACE_ROLES)
    end
  end

  def can_read_route?(space_id)
    return true if can_read_globally?

    org_id = VCAP::CloudController::Space.where(id: space_id).get(:organization_id)
    membership.role_applies?(ROLES_FOR_ROUTE_READING, space_id, org_id)
  end

  def space_guids_with_readable_routes_query
    raise 'must not be called for users that can read globally' if can_read_globally?

    membership.authorized_space_guids_subquery(ROLES_FOR_ROUTE_READING)
  end

  def can_read_app_environment_variables?(space_id, org_id)
    can_read_secrets_globally? ||
      membership.role_applies?(ROLES_FOR_APP_ENVIRONMENT_VARIABLES_READING, space_id, org_id)
  end

  def can_read_system_environment_variables?(space_id, org_id)
    can_read_secrets_globally? ||
      membership.role_applies?(ROLES_FOR_SPACE_SECRETS_READING, space_id, org_id)
  end

  def readable_app_guids
    if can_read_globally?
      VCAP::CloudController::AppModel.select_map(:guid)
    elsif @user
      visible_space_guids = membership.authorized_space_guids_subquery(ROLES_FOR_SPACE_READING)
      VCAP::CloudController::AppModel.where(space_guid: visible_space_guids).select_map(:guid)
    else
      []
    end
  end

  def readable_space_quota_guids
    if can_read_globally?
      VCAP::CloudController::SpaceQuotaDefinition.select_map(:guid)
    elsif @user
      visible_space_ids = membership.authorized_spaces_subquery(SPACE_ROLES).select(:id)
      org_manager_org_ids = membership.authorized_orgs_subquery(VCAP::CloudController::Membership::ORG_MANAGER).select(:id)

      VCAP::CloudController::SpaceQuotaDefinition.where(
        Sequel.or([
          [:id, VCAP::CloudController::Space.where(id: visible_space_ids).
                                            exclude(space_quota_definition_id: nil).
                                            select(:space_quota_definition_id)],
          [:organization_id, org_manager_org_ids]
        ])
      ).select_map(:guid)
    else
      []
    end
  end

  def readable_security_group_guids
    readable_security_group_guids_query.select_map(:guid)
  end

  def readable_security_group_guids_query
    if can_read_globally?
      VCAP::CloudController::SecurityGroup.dataset.select(:guid)
    elsif @user
      visible_space_ids = membership.authorized_spaces_subquery(ROLES_FOR_SPACE_READING).select(:id)

      VCAP::CloudController::SecurityGroup.where(
        Sequel.or([
          [:running_default, true],
          [:staging_default, true],
          [:id, VCAP::CloudController::SecurityGroupsSpace.where(space_id: visible_space_ids).select(:security_group_id).
                union(
                  VCAP::CloudController::StagingSecurityGroupsSpace.where(staging_space_id: visible_space_ids).select(:staging_security_group_id),
                  from_self: false
                )]
        ])
      ).select(:guid)
    else
      VCAP::CloudController::SecurityGroup.where(id: nil).select(:guid)
    end
  end

  def can_update_build_state?
    can_write_globally? || roles.build_state_updater?
  end

  def readable_users_query
    if can_read_globally?
      VCAP::CloudController::User.dataset
    else
      visible_user_ids = membership.visible_user_ids_in_orgs(ROLES_FOR_ORG_READING)
      VCAP::CloudController::User.where(id: visible_user_ids).or(id: @user.id)
    end
  end

  def readable_event_dataset
    return VCAP::CloudController::Event.dataset if can_read_globally?

    spaces_with_permitted_roles = membership.authorized_space_guids(SPACE_ROLES_FOR_EVENTS)
    orgs_with_permitted_roles = membership.authorized_org_guids(VCAP::CloudController::Membership::ORG_AUDITOR)
    VCAP::CloudController::Event.dataset.filter(Sequel.or([
      [:space_guid, spaces_with_permitted_roles],
      [:organization_guid, orgs_with_permitted_roles]
    ]))
  end

  private

  def membership
    @membership ||= VCAP::CloudController::Membership.new(@user)
  end

  def roles
    VCAP::CloudController::SecurityContext.roles
  end
end
