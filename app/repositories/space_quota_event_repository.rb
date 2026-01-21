require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class SpaceQuotaEventRepository
      def record_space_quota_create(quota, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::SPACE_QUOTA_CREATE,
          actee: quota.guid,
          actee_type: 'space_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: quota.organization.guid,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_space_quota_update(quota, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::SPACE_QUOTA_UPDATE,
          actee: quota.guid,
          actee_type: 'space_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: quota.organization.guid,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_space_quota_delete(quota, user_audit_info)
        Event.create(
          type: EventTypes::SPACE_QUOTA_DELETE,
          actee: quota.guid,
          actee_type: 'space_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: quota.organization.guid,
          metadata: {}
        )
      end

      def record_space_quota_apply(quota, space, user_audit_info)
        Event.create(
          type: EventTypes::SPACE_QUOTA_APPLY,
          actee: quota.guid,
          actee_type: 'space_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: space.guid,
          organization_guid: quota.organization.guid,
          metadata: {
            space_guid: space.guid,
            space_name: space.name
          }
        )
      end

      def record_space_quota_remove(quota, space, user_audit_info)
        Event.create(
          type: EventTypes::SPACE_QUOTA_REMOVE,
          actee: quota.guid,
          actee_type: 'space_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: space.guid,
          organization_guid: quota.organization.guid,
          metadata: {
            space_guid: space.guid,
            space_name: space.name
          }
        )
      end
    end
  end
end
