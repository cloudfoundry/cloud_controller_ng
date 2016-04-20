module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      def record_route_create(route, actor, actor_name, request_attrs)
        Event.create(
          space:      route.space,
          type:       'audit.route.create',
          actee:      route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_route_update(route, actor, actor_name, request_attrs)
        Event.create(
          space:      route.space,
          type:       'audit.route.update',
          actee:      route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_route_delete_request(route, actor, actor_name, recursive)
        Event.create(
          type:              'audit.route.delete-request',
          actee:             route.guid,
          actee_type:        'route',
          actee_name:        route.host,
          actor:             actor.guid,
          actor_type:        'user',
          actor_name:        actor_name,
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
