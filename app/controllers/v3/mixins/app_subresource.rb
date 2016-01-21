require 'cloud_controller/membership'

module AppSubresource
  ROLES_FOR_READING =  [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  private

  def can_read?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?(ROLES_FOR_READING, space_guid, org_guid)
  end
end
