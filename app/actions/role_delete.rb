require 'repositories/user_event_repository'

module VCAP::CloudController
  class RoleDeleteAction
    class RoleDeleteError < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(roles)
      roles.each do |role|
        Role.db.transaction do
          model = record_event_and_get_class(role)
          role_to_delete = model.first(role_guid: role.guid)
          role_to_delete.destroy
        end
      end
      []
    end

    private

    def event_repo
      @event_repo ||= Repositories::UserEventRepository.new
    end

    def record_event_and_get_class(role)
      case role.type
      when VCAP::CloudController::RoleTypes::SPACE_MANAGER
        record_space_event(role, 'manager')
        SpaceManager
      when VCAP::CloudController::RoleTypes::SPACE_AUDITOR
        record_space_event(role, 'auditor')
        SpaceAuditor
      when VCAP::CloudController::RoleTypes::SPACE_DEVELOPER
        record_space_event(role, 'developer')
        SpaceDeveloper
      when VCAP::CloudController::RoleTypes::ORGANIZATION_USER
        record_organization_event(role, 'user')
        OrganizationUser
      when VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR
        record_organization_event(role, 'auditor')
        OrganizationAuditor
      when VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER
        record_organization_event(role, 'billing_manager')
        OrganizationBillingManager
      when VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER
        record_organization_event(role, 'manager')
        OrganizationManager
      else
        raise RoleDeleteError.new("Invalid role type: #{role.type}")
      end
    end

    def record_space_event(role, short_event_type)
      space = Space.first(id: role.space_id)
      user = User.first(id: role.user_id)
      event_repo.record_space_role_remove(space, user, short_event_type, @user_audit_info)
    end

    def record_organization_event(role, short_event_type)
      organization = Organization.first(id: role.organization_id)
      user = User.first(id: role.user_id)
      event_repo.record_organization_role_remove(organization, user, short_event_type, @user_audit_info)
    end
  end
end
