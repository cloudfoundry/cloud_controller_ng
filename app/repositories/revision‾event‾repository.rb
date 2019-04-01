module VCAP::CloudController
  module Repositories
    class RevisionEventRepository
      def self.record_create(revision, app, user_audit_info)
        VCAP::Loggregator.emit(revision.app_guid, "Creating revision for app with guid #{app.guid}")

        Event.create(
          type:              'audit.app.revision.create',
          actor:             user_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        user_audit_info.user_email,
          actor_username:    user_audit_info.user_name,
          actee:             app.guid,
          actee_type:        'app',
          actee_name:        app.name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          {
            revision_guid: revision.guid,
            revision_version: revision.version
          },
          space_guid:        app.space_guid,
          organization_guid: app.space.organization_guid,
        )
      end
    end
  end
end
