class VCAP::CloudController::Permissions
  ROLES_FOR_READING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ROLES_FOR_SECRETS ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  ROLES_FOR_WRITING ||= [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
  ].freeze

  def initialize(user)
    @user = user
  end

  def can_read_from_space?(space_guid, org_guid)
    roles.admin? || roles.admin_read_only? ||
      membership.has_any_roles?(ROLES_FOR_READING, space_guid, org_guid)
  end

  def can_see_secrets_in_space?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?(ROLES_FOR_SECRETS, space_guid, org_guid)
  end

  def can_write_to_space?(space_guid)
    roles.admin? || membership.has_any_roles?(ROLES_FOR_WRITING, space_guid)
  end

  def readable_space_guids
    membership.space_guids_for_roles(ROLES_FOR_READING)
  end

  private

  def membership
    VCAP::CloudController::Membership.new(@user)
  end

  def roles
    VCAP::CloudController::SecurityContext.roles
  end
end
