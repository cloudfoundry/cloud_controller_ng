module VCAP::CloudController
  module Repositories
    module Runtime
      class OrganizationEventRepository
        def record_organization_delete_request(organization, actor, actor_name)
          Event.create(
            type: 'audit.organization.delete-request',
            actee: organization.guid,
            actee_type: 'organization',
            actee_name: organization.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            organization_guid: organization.guid
          )
        end
      end
    end
  end
end
