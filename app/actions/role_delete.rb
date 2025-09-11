require 'repositories/user_event_repository'

module VCAP::CloudController
  class RoleDeleteAction
    class RoleDeleteError < StandardError
    end

    def initialize(user_audit_info, role_owner, role_owner_username)
      @user_audit_info = user_audit_info
      @role_owner = role_owner
      @role_owner_username = role_owner_username
    end

    def delete(roles)
      @role_owner.username = @role_owner_username if @role_owner_username.present?
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
      if role.type.in?(RoleTypes::SPACE_ROLES)
        event_repo.record_space_role_remove(Space.first(id: role.space_id), @role_owner, role.type, @user_audit_info)
      elsif role.type.in?(RoleTypes::ORGANIZATION_ROLES)
        event_repo.record_organization_role_remove(Organization.first(id: role.organization_id), @role_owner, role.type, @user_audit_info)
      else
        raise RoleDeleteError.new("Invalid role type: #{role.type}")
      end
    end
  end
end
