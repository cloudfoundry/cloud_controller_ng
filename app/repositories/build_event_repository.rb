module VCAP::CloudController
  module Repositories
    class BuildEventRepository
      def self.record_build_create(build, user_audit_info, v3_app_name, space_guid, org_guid)
        Loggregator.emit(build.app_guid, "Creating build for app with guid #{build.app_guid}")

        metadata = {
          build_guid: build.guid,
          package_guid: build.package.guid,
        }

        Event.create(
          type:              'audit.app.build.create',
          actor:             user_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        user_audit_info.user_email,
          actor_username:    user_audit_info.user_name,
          actee:             build.app_guid,
          actee_type:        'app',
          actee_name:        v3_app_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata,
          space_guid:        space_guid,
          organization_guid: org_guid
        )
      end
    end
  end
end
