module VCAP::CloudController
  module Repositories
    module Runtime
      class SpaceEventRepository
        def record_space_create(space, actor, request_attrs)
          Event.create(
            space: space,
            type: "audit.space.create",
            actee: space.guid,
            actee_type: "space",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
            metadata: {
              request: request_attrs
            }
          )
        end

        def record_space_update(space, actor, request_attrs)
          Event.create(
            space: space,
            type: "audit.space.update",
            actee: space.guid,
            actee_type: "space",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
            metadata: {
              request: request_attrs
            }
          )
        end

        def record_space_delete_request(space, actor, recursive)
          Event.create(
            type: "audit.space.delete-request",
            actee: space.guid,
            actee_type: "space",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
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
