module VCAP::CloudController
  module Repositories
    class OrganizationEventRepository
      def record_organization_create(organization, actor, actor_name, request_attrs)
        Event.create(
          type:       'audit.organization.create',
          actee:      organization.guid,
          organization_guid: organization.guid,
          actee_type: 'organization',
          actee_name: organization.name,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_organization_update(organization, actor, actor_name, request_attrs)
        Event.create(
          type:       'audit.organization.update',
          actee:      organization.guid,
          organization_guid: organization.guid,
          actee_type: 'organization',
          actee_name: organization.name,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_organization_delete_request(organization, actor, actor_name, request_attrs)
        Event.create(
          type:              'audit.organization.delete-request',
          actee:             organization.guid,
          organization_guid: organization.guid,
          actee_type:        'organization',
          actee_name:        organization.name,
          actor:             actor.guid,
          actor_type:        'user',
          actor_name:        actor_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          {
            request: request_attrs
          }
        )
      end
    end
  end
end
