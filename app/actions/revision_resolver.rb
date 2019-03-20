require 'actions/revision_create'

module VCAP::CloudController
  class RevisionResolver
    class << self
      def update_app_revision(app, user_audit_info)
        return nil unless app.revisions_enabled

        latest_revision = app.latest_revision
        if latest_revision.nil?
          return RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: app.environment_variables,
            description: 'Initial revision.',
            commands_by_process_type: app.commands_by_process_type,
            user_audit_info: user_audit_info,
          )
        end

        reasons = latest_revision.out_of_date_reasons
        if !reasons.empty?
          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: app.environment_variables,
            description: reasons.join(' '),
            commands_by_process_type: app.commands_by_process_type,
            user_audit_info: user_audit_info,
          )
        else
          latest_revision
        end
      end

      def rollback_app_revision(revision, user_audit_info)
        return nil unless revision.app.revisions_enabled

        RevisionCreate.create(
          app: revision.app,
          droplet_guid: revision.droplet_guid,
          environment_variables: revision.environment_variables,
          description: "Rolled back to revision #{revision.version}.",
          commands_by_process_type: revision.commands_by_process_type,
          user_audit_info: user_audit_info,
        )
      end
    end
  end
end
