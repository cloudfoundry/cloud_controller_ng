require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class RoutePolicyEventRepository
      def record_route_policy_create(route_policy, actor_audit_info, request_attrs)
        Event.create(
          space: route_policy.route.space,
          type: EventTypes::ROUTE_POLICY_CREATE,
          actee: route_policy.guid,
          actee_type: 'route_policy',
          actee_name: route_policy.source,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: { request: request_attrs }
        )
      end

      def record_route_policy_update(route_policy, actor_audit_info, request_attrs)
        Event.create(
          space: route_policy.route.space,
          type: EventTypes::ROUTE_POLICY_UPDATE,
          actee: route_policy.guid,
          actee_type: 'route_policy',
          actee_name: route_policy.source,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: { request: request_attrs }
        )
      end

      def record_route_policy_delete(route_policy, actor_audit_info)
        Event.create(
          space: route_policy.route.space,
          type: EventTypes::ROUTE_POLICY_DELETE,
          actee: route_policy.guid,
          actee_type: 'route_policy',
          actee_name: route_policy.source,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {}
        )
      end
    end
  end
end
