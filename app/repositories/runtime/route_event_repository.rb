module VCAP::CloudController
  module Repositories
    module Runtime
      class RouteEventRepository
        def record_route_delete_request(route, actor, actor_name)
          Event.create(
            type: 'audit.route.delete-request',
            actee: route.guid,
            actee_type: 'route',
            actee_name: route.fqdn,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            organization_guid: route.space.organization.guid,
            space_guid: route.space.guid
          )
        end
      end
    end
  end
end
