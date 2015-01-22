module VCAP::CloudController
  module Repositories
    module Runtime
      class SpaceEventRepository
        def record_space_create(space, actor, actor_name, request_attrs)
          Event.create(
            space: space,
            type: 'audit.space.create',
            actee: space.guid,
            actee_type: 'space',
            actee_name: space.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            metadata: {
              request: request_attrs
            }
          )
        end

        def record_space_update(space, actor, actor_name, request_attrs)
          Event.create(
            space: space,
            type: 'audit.space.update',
            actee: space.guid,
            actee_type: 'space',
            actee_name: space.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            metadata: {
              request: request_attrs
            }
          )
        end

        def record_space_delete_request(space, actor, actor_name, recursive)
          Event.create(
            type: 'audit.space.delete-request',
            actee: space.guid,
            actee_type: 'space',
            actee_name: space.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            space_guid: space.guid,
            organization_guid: space.organization.guid,
            metadata: {
              request: { recursive: recursive }
            }
          )
        end
      end
    end
  end
end
