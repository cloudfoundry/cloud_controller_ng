require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class OrganizationQuotaEventRepository
      def record_organization_quota_create(quota, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::ORGANIZATION_QUOTA_CREATE,
          actee: quota.guid,
          actee_type: 'organization_quota',
          actee_name: quota.name,
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

      def record_organization_quota_update(quota, user_audit_info, request_attrs)
        Event.create(
          type: EventTypes::ORGANIZATION_QUOTA_UPDATE,
          actee: quota.guid,
          actee_type: 'organization_quota',
          actee_name: quota.name,
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

      def record_organization_quota_delete(quota, user_audit_info)
        Event.create(
          type: EventTypes::ORGANIZATION_QUOTA_DELETE,
          actee: quota.guid,
          actee_type: 'organization_quota',
          actee_name: quota.name,
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

      def record_organization_quota_apply(quota, organization, user_audit_info)
        Event.create(
          type: EventTypes::ORGANIZATION_QUOTA_APPLY,
          actee: quota.guid,
          actee_type: 'organization_quota',
          actee_name: quota.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: '',
          organization_guid: organization.guid,
          metadata: {
            organization_guid: organization.guid,
            organization_name: organization.name
          }
        )
      end
    end
  end
end
