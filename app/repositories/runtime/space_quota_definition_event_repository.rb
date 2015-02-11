module VCAP::CloudController
  module Repositories
    module Runtime
      class SpaceQuotaDefinitionEventRepository
        def record_space_quota_definition_delete_request(space_quota_definition, actor, actor_name)
          Event.create(
            type: 'audit.space_quota_definition.delete-request',
            actee: space_quota_definition.guid,
            actee_type: 'space_quota_definition',
            actee_name: space_quota_definition.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            space_guid: '',
            organization_guid: space_quota_definition.organization.guid
          )
        end
      end
    end
  end
end
