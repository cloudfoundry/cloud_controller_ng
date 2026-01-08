require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class BuildpackEventRepository
      def record_buildpack_create(buildpack, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::BUILDPACK_CREATE,
          actee: buildpack.guid,
          actee_type: 'buildpack',
          actee_name: buildpack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_buildpack_update(buildpack, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::BUILDPACK_UPDATE,
          actee: buildpack.guid,
          actee_type: 'buildpack',
          actee_name: buildpack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_buildpack_delete(buildpack, user_audit_info)
        Event.create(
          type: EventTypes::BUILDPACK_DELETE,
          actee: buildpack.guid,
          actee_type: 'buildpack',
          actee_name: buildpack.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: '',
          metadata: {}
        )
      end
    end
  end
end
