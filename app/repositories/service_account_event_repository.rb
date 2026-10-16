module VCAP::CloudController
  module Repositories
    class ServiceAccountEventRepository
      def self.record(resource, operation, actor, metadata={})
        Event.create(
          type: "audit.#{resource.is_a?(AppModel) ? 'app.service_account' : 'service_account'}.#{operation}",
          space: resource.space,
          actee: resource.guid,
          actee_type: resource.is_a?(AppModel) ? 'app' : 'service_account',
          actee_name: resource.name,
          actor: actor.user_guid,
          actor_type: 'user',
          actor_name: actor.user_email,
          actor_username: actor.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata
        )
      end
    end
  end
end
