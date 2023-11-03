require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class UserEventRepository
      def record_space_role_add(space, assignee, role_type, actor_audit_info, request_attrs={})
        record_space_role_event(EventTypes.get("USER_#{role_type}_ADD"), space, assignee, actor_audit_info, request_attrs)
      end

      def record_space_role_remove(space, assignee, role_type, actor_audit_info, request_attrs={})
        record_space_role_event(EventTypes.get("USER_#{role_type}_REMOVE"), space, assignee, actor_audit_info, request_attrs)
      end

      def record_organization_role_add(organization, assignee, role_type, actor_audit_info, request_attrs={})
        record_organization_role_event(EventTypes.get("USER_#{role_type}_ADD"), organization, assignee, actor_audit_info, request_attrs)
      end

      def record_organization_role_remove(organization, assignee, role_type, actor_audit_info, request_attrs={})
        record_organization_role_event(EventTypes.get("USER_#{role_type}_REMOVE"), organization, assignee, actor_audit_info, request_attrs)
      end

      private

      def record_space_role_event(type, space, assignee, actor_audit_info, request_attrs)
        username = assignee.username || ''
        Event.create(
          type: type,
          space: space,
          actee: assignee.guid,
          actee_type: 'user',
          actee_name: username,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_organization_role_event(type, organization, assignee, actor_audit_info, request_attrs)
        username = assignee.username || ''
        Event.create(
          type: type,
          organization_guid: organization.guid,
          actee: assignee.guid,
          actee_type: 'user',
          actee_name: username,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end
    end
  end
end
