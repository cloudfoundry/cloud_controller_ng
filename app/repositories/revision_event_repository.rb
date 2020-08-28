module VCAP::CloudController
  module Repositories
    class RevisionEventRepository
      def self.record_create(revision, app, user_audit_info)
        VCAP::AppLogEmitter.emit(revision.app_guid, "Creating revision for app with guid #{app.guid}")
        create_revision_event('audit.app.revision.create', app, revision, user_audit_info)
      end

      def self.record_show_environment_variables(revision, app, user_audit_info)
        create_revision_event('audit.app.revision.environment_variables.show', app, revision, user_audit_info)
      end

      def self.create_revision_event(type, app, revision, user_audit_info)
        Event.create(
          type: type,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          actee: app.guid,
          actee_type: 'app',
          actee_name: app.name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            revision_guid: revision.guid,
            revision_version: revision.version
          },
          space_guid: app.space_guid,
          organization_guid: app.space.organization_guid,
        )
      end

      private_class_method :create_revision_event
    end
  end
end
