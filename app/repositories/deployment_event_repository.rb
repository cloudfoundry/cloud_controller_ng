require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class DeploymentEventRepository
      def self.record_create(deployment, droplet, user_audit_info, v3_app_name, space_guid, org_guid, params, type)
        VCAP::AppLogEmitter.emit(deployment.app_guid, "Creating deployment for app with guid #{deployment.app_guid}")

        metadata = {
          deployment_guid: deployment.guid,
          droplet_guid: droplet&.guid,
          type: type,
          revision_guid: deployment.revision_guid,
          request: params,
          strategy: deployment.strategy
        }

        Event.create(
          type: EventTypes::APP_DEPLOYMENT_CREATE,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: deployment.app_guid,
          actee_type: 'app',
          actee_name: v3_app_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: space_guid,
          organization_guid: org_guid
        )
      end

      def self.record_cancel(deployment, droplet, user_audit_info, v3_app_name, space_guid, org_guid)
        VCAP::AppLogEmitter.emit(deployment.app_guid, "Cancelling deployment for app with guid #{deployment.app_guid}")

        metadata = {
          deployment_guid: deployment.guid,
          droplet_guid: droplet&.guid
        }

        Event.create(
          type: EventTypes::APP_DEPLOYMENT_CANCEL,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: deployment.app_guid,
          actee_type: 'app',
          actee_name: v3_app_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: space_guid,
          organization_guid: org_guid
        )
      end

      def self.record_continue(deployment, droplet, user_audit_info, v3_app_name, space_guid, org_guid)
        VCAP::AppLogEmitter.emit(deployment.app_guid, "Continuing deployment for app with guid #{deployment.app_guid}")

        metadata = {
          deployment_guid: deployment.guid,
          droplet_guid: droplet&.guid
        }

        Event.create(
          type: EventTypes::APP_DEPLOYMENT_CONTINUE,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: deployment.app_guid,
          actee_type: 'app',
          actee_name: v3_app_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: space_guid,
          organization_guid: org_guid
        )
      end
    end
  end
end
