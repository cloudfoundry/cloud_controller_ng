module VCAP::CloudController
  module Repositories
    module Runtime
      class ServiceAuthTokenEventRepository
        def record_service_auth_token_delete_request(service_auth_token, actor, actor_name)
          Event.create(
            type: 'audit.service_auth_token.delete-request',
            actee: service_auth_token.guid,
            actee_type: 'service_auth_token',
            actee_name: service_auth_token.label,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            organization_guid: ''
          )
        end
      end
    end
  end
end
