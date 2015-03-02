module VCAP::CloudController
  module Repositories
    module Runtime
      class QuotaDefinitionEventRepository
        def record_quota_definition_delete_request(quota_definition, actor, actor_name)
          Event.create(
            type: 'audit.quota_definition.delete-request',
            actee: quota_definition.guid,
            actee_type: 'quota_definition',
            actee_name: quota_definition.name,
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
