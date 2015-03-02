module VCAP::CloudController
  module Repositories
    module Runtime
      class UserEventRepository
        def record_user_delete_request(user, actor, actor_name)
          Event.create(
            type: 'audit.user.delete-request',
            actee: user.guid,
            actee_type: 'user',
            actee_name: user.guid,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
          )
        end
      end
    end
  end
end
