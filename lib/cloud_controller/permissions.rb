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
  ].freeze

  ORG_ROLES_FOR_READING_DOMAINS_FROM_ORGS ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR,
  ].freeze

  SPACE_ROLES ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
  ].freeze

  ROLES_FOR_SPACE_SECRETS_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_SPACE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_SPACE_UPDATING ||= [
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_ROUTE_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

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
    if can_read_globally?
      VCAP::CloudController::Organization.select(:guid).all.map(&:guid)
    else
      membership.org_guids_for_roles(ROLES_FOR_ORG_READING)
    end
  end

  def readable_org_guids_for_domains
    if can_read_globally?
      VCAP::CloudController::Organization.select(:guid).all.map(&:guid)
    else
      # Getting readable orgs for org-scoped roles
      org_guids = membership.org_guids_for_roles(ORG_ROLES_FOR_READING_DOMAINS_FROM_ORGS)

      # Getting readable orgs for space-scoped roles
      space_guids = membership.space_guids_for_roles(SPACE_ROLES)
      org_guids_from_space_guids = space_guids.map { |guid| VCAP::CloudController::Space.find(guid: guid).organization.guid }

      (org_guids + org_guids_from_space_guids).uniq
    end
  end

  def readable_org_contents_org_guids
    if can_read_globally?
      VCAP::CloudController::Organization.select(:guid).all.map(&:guid)
    else
      membership.org_guids_for_roles(ROLES_FOR_ORG_CONTENT_READING)
    end
  end

  def can_read_from_org?(org_guid)
    can_read_globally? || membership.has_any_roles?(ROLES_FOR_ORG_READING, nil, org_guid)
  end

  def can_write_to_org?(org_guid)
    return true if can_write_globally?
    return false unless membership.has_any_roles?(ROLES_FOR_ORG_WRITING, nil, org_guid)

    VCAP::CloudController::Organization.find(guid: org_guid)&.active?
  end

  def readable_space_guids
    if can_read_globally?
      VCAP::CloudController::Space.select(:guid).all.map(&:guid)
    else
      membership.space_guids_for_roles(ROLES_FOR_SPACE_READING)
    end
  end

  def can_read_from_space?(space_guid, org_guid)
    can_read_globally? || membership.has_any_roles?(ROLES_FOR_SPACE_READING, space_guid, org_guid)
  end

  def can_read_secrets_in_space?(space_guid, org_guid)
    can_read_secrets_globally? ||
      membership.has_any_roles?(ROLES_FOR_SPACE_SECRETS_READING, space_guid, org_guid)
  end

  def can_write_to_space?(space_guid)
    return true if can_write_globally?
    return false unless membership.has_any_roles?(ROLES_FOR_SPACE_WRITING, space_guid)

    VCAP::CloudController::Space.find(guid: space_guid)&.organization&.active?
  end

  def can_update_space?(space_guid, org_guid)
    return true if can_write_globally?
    return false unless membership.has_any_roles?(ROLES_FOR_SPACE_UPDATING, space_guid, org_guid)

    VCAP::CloudController::Space.find(guid: space_guid)&.organization&.active?
  end

  def can_read_from_isolation_segment?(isolation_segment)
    can_read_globally? ||
      isolation_segment.spaces.any? { |space| can_read_from_space?(space.guid, space.organization.guid) } ||
      isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
  end

  def readable_route_guids
    readable_route_dataset.map(&:guid)
  end

  def readable_route_dataset
    if can_read_globally?
      VCAP::CloudController::Route.dataset
    else
      VCAP::CloudController::Route.user_visible(@user, can_read_globally?)
    end
  end

  def readable_secret_space_guids
    if can_read_secrets_globally?
      VCAP::CloudController::Space.select(:guid).all.map(&:guid)
    else
      membership.space_guids_for_roles(ROLES_FOR_SPACE_SECRETS_READING)
    end
  end

  def readable_space_scoped_space_guids
    if can_read_globally?
      VCAP::CloudController::Space.select(:guid).all.map(&:guid)
    else
      membership.space_guids_for_roles(SPACE_ROLES)
    end
  end

  def can_read_route?(space_guid, org_guid)
    return true if can_read_globally?

    space = VCAP::CloudController::Space.where(guid: space_guid).first
    org = space.organization

    space.has_member?(@user) || @user.managed_organizations.include?(org) ||
      @user.audited_organizations.include?(org)
  end

  def readable_app_guids
    VCAP::CloudController::AppModel.user_visible(@user, can_read_globally?).map(&:guid)
  end

  def readable_route_mapping_guids
    VCAP::CloudController::RouteMappingModel.user_visible(@user, can_read_globally?).map(&:guid)
  end

  def readable_space_quota_guids
    VCAP::CloudController::SpaceQuotaDefinition.user_visible(@user, can_read_globally?).map(&:guid)
  end

  def readable_security_group_guids
    VCAP::CloudController::SecurityGroup.user_visible(@user, can_read_globally?).map(&:guid)
  end

  def can_update_build_state?
    can_write_globally? || roles.build_state_updater?
  end

  private

  def membership
    VCAP::CloudController::Membership.new(@user)
  end

  def roles
    VCAP::CloudController::SecurityContext.roles
  end
end
