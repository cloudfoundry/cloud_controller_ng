require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class BuildEventRepository
      def self.record_build_create(build, user_audit_info, v3_app_name, space_guid, org_guid)
        VCAP::AppLogEmitter.emit(build.app_guid, "Creating build for app with guid #{build.app_guid}")

        metadata = {
          build_guid: build.guid,
          package_guid: build.package_guid
        }

        Event.create(
          type: EventTypes::APP_BUILD_CREATE,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: build.app_guid,
          actee_type: 'app',
          actee_name: v3_app_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: space_guid,
          organization_guid: org_guid
        )
      end

      def self.record_build_staged(build, droplet)
        app = build.app
        VCAP::AppLogEmitter.emit(app.guid, "Staging complete for build #{build.guid}")

        metadata = {
          build_guid: build.guid,
          package_guid: build.package_guid,
          droplet_guid: droplet.guid,
          buildpacks: buildpack_info(droplet)
        }

        Event.create(
          type: EventTypes::APP_BUILD_STAGED,
          actor: build.created_by_user_guid || UserAuditInfo::DATA_UNAVAILABLE,
          actor_type: 'user',
          actor_name: build.created_by_user_email,
          actor_username: build.created_by_user_name,
          actee: app.guid,
          actee_type: 'app',
          actee_name: app.name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: app.space_guid,
          organization_guid: app.space.organization_guid
        )
      end

      def self.record_build_failed(build, error_id, error_message)
        app = build.app
        VCAP::AppLogEmitter.emit(app.guid, "Staging failed for build #{build.guid}")

        metadata = {
          build_guid: build.guid,
          package_guid: build.package_guid,
          error_id: error_id,
          error_message: error_message
        }

        Event.create(
          type: EventTypes::APP_BUILD_FAILED,
          actor: build.created_by_user_guid || UserAuditInfo::DATA_UNAVAILABLE,
          actor_type: 'user',
          actor_name: build.created_by_user_email,
          actor_username: build.created_by_user_name,
          actee: app.guid,
          actee_type: 'app',
          actee_name: app.name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: metadata,
          space_guid: app.space_guid,
          organization_guid: app.space.organization_guid
        )
      end

      def self.buildpack_info(droplet)
        return nil if droplet.docker?

        droplet.lifecycle_data.buildpack_lifecycle_buildpacks.map do |buildpack|
          {
            name: buildpack.admin_buildpack_name || CloudController::UrlSecretObfuscator.obfuscate(buildpack.buildpack_url),
            buildpack_name: buildpack.buildpack_name,
            version: buildpack.version
          }
        end
      end
      private_class_method :buildpack_info
    end
  end
end
