require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class StackEventRepository
      def record_stack_create(stack, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::STACK_CREATE,
          actee: stack.guid,
          actee_type: 'stack',
          actee_name: stack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_stack_update(stack, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::STACK_UPDATE,
          actee: stack.guid,
          actee_type: 'stack',
          actee_name: stack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_stack_delete(stack, user_audit_info)
        Event.create(
          type: EventTypes::STACK_DELETE,
          actee: stack.guid,
          actee_type: 'stack',
          actee_name: stack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {}
        )
      end
    end
  end
end
