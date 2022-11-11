class VCAP::CloudController::Permissions
  ROLES_FOR_ORG_READING ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR,
    VCAP::CloudController::Membership::ORG_USER,
    VCAP::CloudController::Membership::ORG_BILLING_MANAGER,
  ].freeze

  ROLES_FOR_ORG_CONTENT_READING = [
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_ORG_WRITING = [
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_SPACE_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER,
  ].freeze

  ROLES_FOR_DROPLET_DOWLOAD ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ORG_ROLES_FOR_READING_DOMAINS_FROM_ORGS ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR,
  ].freeze

  SPACE_ROLES ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::SPACE_SUPPORTER,
  ].freeze

  SPACE_ROLES_FOR_EVENTS ||= [
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  ROLES_FOR_SPACE_SECRETS_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_SPACE_SERVICES_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_SUPPORTER
  ].freeze

  ROLES_FOR_ROUTE_READING ||= ROLES_FOR_SPACE_READING + [
    VCAP::CloudController::Membership::ORG_AUDITOR
  ].freeze

  ROLES_FOR_SPACE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_APP_MANAGING ||= (ROLES_FOR_SPACE_WRITING + [
    VCAP::CloudController::Membership::SPACE_SUPPORTER,
  ]).freeze

  ROLES_FOR_SPACE_UPDATING ||= [
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_ROUTE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_APP_ENVIRONMENT_VARIABLES_READING ||= (ROLES_FOR_SPACE_SECRETS_READING + [
    VCAP::CloudController::Membership::SPACE_SUPPORTER,
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

  def readable_org_guids
    readable_org_guids_query.select_map(:guid)
  end

  def readable_org_guids_query
    if can_read_globally?
      raise 'must not be called for users that can read globally'
    else
      membership.authorized_org_guids_subquery(ROLES_FOR_ORG_READING)
    end
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

  def readable_space_guids
    readable_space_guids_query.select_map(:guid)
  end

  def readable_space_guids_query
    if can_read_globally?
      raise 'must not be called for users that can read globally'
    else
      membership.authorized_space_guids_subquery(ROLES_FOR_SPACE_READING)
    end
  end

  def can_read_from_space?(space_id, org_id)
    can_read_globally? || membership.role_applies?(ROLES_FOR_SPACE_READING, space_id, org_id)
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

  def readable_route_dataset
    if can_read_globally?
      VCAP::CloudController::Route.dataset
    else
      VCAP::CloudController::Route.user_visible(@user, can_read_globally?)
    end
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

    space = VCAP::CloudController::Space.where(id: space_id).first

    space.has_member?(@user) || space.has_supporter?(@user) ||
      @user.managed_organizations.map(&:id).include?(space.organization_id) ||
      @user.audited_organizations.map(&:id).include?(space.organization_id)
  end

  def space_guids_with_readable_routes_query
    if can_read_globally?
      raise 'must not be called for users that can read globally'
    else
      membership.authorized_space_guids_subquery(ROLES_FOR_ROUTE_READING)
    end
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
    VCAP::CloudController::AppModel.user_visible(@user, can_read_globally?).select(:guid).map(&:guid)
  end

  def readable_space_quota_guids
    VCAP::CloudController::SpaceQuotaDefinition.user_visible(@user, can_read_globally?).map(&:guid)
  end

  def readable_security_group_guids
    readable_security_group_guids_query.select_map(:guid)
  end

  def readable_security_group_guids_query
    VCAP::CloudController::SecurityGroup.user_visible(@user, can_read_globally?).select(:guid)
  end

  def can_update_build_state?
    can_write_globally? || roles.build_state_updater?
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
