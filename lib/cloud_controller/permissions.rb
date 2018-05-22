class VCAP::CloudController::Permissions
  ROLES_FOR_ORG_READING ||= [
    VCAP::CloudController::Membership::ORG_MANAGER,
    VCAP::CloudController::Membership::ORG_AUDITOR,
    VCAP::CloudController::Membership::ORG_MEMBER,
    VCAP::CloudController::Membership::ORG_BILLING_MANAGER,
  ].freeze

  ROLES_FOR_ORG_WRITING = [
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER,
  ].freeze

  ROLES_FOR_SECRETS ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  ROLES_FOR_WRITING ||= [
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

  def can_read_from_org?(org_guid)
    can_read_globally? || membership.has_any_roles?(ROLES_FOR_ORG_READING, nil, org_guid)
  end

  def can_write_to_org?(org_guid)
    can_write_globally? || membership.has_any_roles?(ROLES_FOR_ORG_WRITING, nil, org_guid)
  end

  def readable_space_guids
    if can_read_globally?
      VCAP::CloudController::Space.select(:guid).all.map(&:guid)
    else
      membership.space_guids_for_roles(ROLES_FOR_READING)
    end
  end

  def can_read_from_space?(space_guid, org_guid)
    can_read_globally? || membership.has_any_roles?(ROLES_FOR_READING, space_guid, org_guid)
  end

  def can_read_secrets_in_space?(space_guid, org_guid)
    can_read_secrets_globally? ||
      membership.has_any_roles?(ROLES_FOR_SECRETS, space_guid, org_guid)
  end

  def can_write_to_space?(space_guid)
    can_write_globally? || membership.has_any_roles?(ROLES_FOR_WRITING, space_guid)
  end

  def can_read_from_isolation_segment?(isolation_segment)
    can_read_globally? ||
      isolation_segment.spaces.any? { |space| can_read_from_space?(space.guid, space.organization.guid) } ||
      isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
  end

  def readable_route_guids
    VCAP::CloudController::Route.user_visible(@user, can_read_globally?).map(&:guid)
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

  private

  def membership
    VCAP::CloudController::Membership.new(@user)
  end

  def roles
    VCAP::CloudController::SecurityContext.roles
  end
end
