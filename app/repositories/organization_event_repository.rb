require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class OrganizationEventRepository
      def record_organization_create(organization, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::ORGANIZATION_CREATE,
          actee: organization.guid,
          organization_guid: organization.guid,
          actee_type: 'organization',
          actee_name: organization.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_organization_update(organization, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::ORGANIZATION_UPDATE,
          actee: organization.guid,
          organization_guid: organization.guid,
          actee_type: 'organization',
          actee_name: organization.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_organization_delete_request(organization, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::ORGANIZATION_DELETE_REQUEST,
          actee: organization.guid,
          organization_guid: organization.guid,
          actee_type: 'organization',
          actee_name: organization.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end
    end
  end
end
