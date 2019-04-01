module VCAP::CloudController
  module Repositories
    class SpaceEventRepository
      def record_space_create(space, user_audit_info, request_attrs)
        Event.create(
          space:          space,
          type:           'audit.space.create',
          actee:          space.guid,
          actee_type:     'space',
          actee_name:     space.name,
          actor:          user_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            request: request_attrs
          }
        )
      end

      def record_space_update(space, user_audit_info, request_attrs)
        Event.create(
          space:          space,
          type:           'audit.space.update',
          actee:          space.guid,
          actee_type:     'space',
          actee_name:     space.name,
          actor:          user_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            request: request_attrs
          }
        )
      end

      def record_space_delete_request(space, user_audit_info, recursive)
        Event.create(
          type:              'audit.space.delete-request',
          actee:             space.guid,
          actee_type:        'space',
          actee_name:        space.name,
          actor:             user_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        user_audit_info.user_email,
          actor_username:    user_audit_info.user_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        space.guid,
          organization_guid: space.organization.guid,
          metadata:          {
            request: { recursive: recursive }
          }
        )
      end
    end
  end
end
