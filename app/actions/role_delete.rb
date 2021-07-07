require 'repositories/user_event_repository'

module VCAP::CloudController
  class RoleDeleteAction
    class RoleDeleteError < StandardError
    end

    def initialize(user_audit_info, role_owner)
      @user_audit_info = user_audit_info
      @role_owner = role_owner
    end

    def delete(roles)
      roles.each do |role|
        Role.db.transaction do
          record_event(role)
          role_to_delete = role.model_class.first(role_guid: role.guid)
          role_to_delete.destroy
        end
      end
      []
    end

    private

    def event_repo
      @event_repo ||= Repositories::UserEventRepository.new
    end

    def record_event(role)
      case role.type
      when VCAP::CloudController::RoleTypes::SPACE_MANAGER
        record_space_event(role, 'manager')
      when VCAP::CloudController::RoleTypes::SPACE_AUDITOR
        record_space_event(role, 'auditor')
      when VCAP::CloudController::RoleTypes::SPACE_DEVELOPER
        record_space_event(role, 'developer')
      when VCAP::CloudController::RoleTypes::SPACE_SUPPORTER
        record_space_event(role, 'supporter')
      when VCAP::CloudController::RoleTypes::ORGANIZATION_USER
        record_organization_event(role, 'user')
      when VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR
        record_organization_event(role, 'auditor')
      when VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER
        record_organization_event(role, 'billing_manager')
      when VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER
        record_organization_event(role, 'manager')
      else
        raise RoleDeleteError.new("Invalid role type: #{role.type}")
      end
    end

    def record_space_event(role, short_event_type)
      space = Space.first(id: role.space_id)
      event_repo.record_space_role_remove(space, @role_owner, short_event_type, @user_audit_info)
    end

    def record_organization_event(role, short_event_type)
      organization = Organization.first(id: role.organization_id)
      event_repo.record_organization_role_remove(organization, @role_owner, short_event_type, @user_audit_info)
    end
  end
end
