module VCAP::CloudController
  module Repositories
    module Runtime
      class BuildpackEventRepository
        def record_buildpack_delete_request(buildpack, actor, actor_name)
          Event.create(
            type: 'audit.buildpack.delete-request',
            actee: buildpack.guid,
            actee_type: 'buildpack',
            actee_name: buildpack.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP
          )
        end
      end
    end
  end
end
