module VCAP::CloudController
  class RoleDeleteAction
    class RoleDeleteError < StandardError; end

    def delete(roles)
      roles.each do |role|
        Role.db.transaction do
          model = role_class(role)
          role_to_delete = model.where(role_guid: role.guid).first
          role_to_delete.destroy
        end
      end
      []
    end

    private

    def role_class(role)
      case role.type
      when VCAP::CloudController::RoleTypes::SPACE_MANAGER
        SpaceManager
      when VCAP::CloudController::RoleTypes::SPACE_AUDITOR
        SpaceAuditor
      when VCAP::CloudController::RoleTypes::SPACE_DEVELOPER
        SpaceDeveloper
      when VCAP::CloudController::RoleTypes::ORGANIZATION_USER
        OrganizationUser
      when VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR
        OrganizationAuditor
      when VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER
        OrganizationBillingManager
      when VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER
        OrganizationManager
      else
        raise RoleDeleteError.new("Invalid role type: #{role.type}")
      end
    end
  end
end
