module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      def record_route_create(route, actor_audit_info, request_attrs)
        Event.create(
          space:          route.space,
          type:           'audit.route.create',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            request: request_attrs
          }
        )
      end

      def record_route_update(route, actor_audit_info, request_attrs)
        Event.create(
          space:          route.space,
          type:           'audit.route.update',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            request: request_attrs
          }
        )
      end

      def record_route_delete_request(route, actor_audit_info, recursive)
        Event.create(
          type:              'audit.route.delete-request',
          actee:             route.guid,
          actee_type:        'route',
          actee_name:        route.host,
          actor:             actor_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        actor_audit_info.user_email,
          actor_username:    actor_audit_info.user_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        route.space.guid,
          organization_guid: route.space.organization.guid,
          metadata:          {
            request: { recursive: recursive }
          }
        )
      end
    end
  end
end
