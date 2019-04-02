require 'repositories/revision_event_repository'

module VCAP::CloudController
  class RevisionCreate
    class << self
      def create(app:, droplet_guid:, environment_variables:, description:, commands_by_process_type:, user_audit_info:)
        RevisionModel.db.transaction do
          next_version = calculate_next_version(app)

          if (existing_revision_for_version = RevisionModel.find(app: app, version: next_version))
            existing_revision_for_version.destroy
          end

          revision = RevisionModel.create(
            app: app,
            version: next_version,
            droplet_guid: droplet_guid,
            environment_variables: environment_variables,
            description: description,
          )

          commands_by_process_type.
            each { |process_type, command| revision.add_command_for_process_type(process_type, command) }

          record_audit_event(revision, user_audit_info) if user_audit_info

          revision
        end
      end

      private

      def calculate_next_version(app)
        previous_revision = app.latest_revision
        return 1 if previous_revision.nil? || previous_revision.version >= 9999

        previous_revision.version + 1
      end

      def record_audit_event(revision, user_audit_info)
        Repositories::RevisionEventRepository.record_create(revision, revision.app, user_audit_info)
      end
    end
  end
end
