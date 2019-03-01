require 'repositories/revision_event_repository'
module VCAP::CloudController
  class RevisionCreate
    class << self
      def create(app, user_audit_info)
        RevisionModel.db.transaction do
          next_version = calculate_next_version(app)

          if (existing_revision_for_version = RevisionModel.find(app: app, version: next_version))
            existing_revision_for_version.destroy
          end

          revision = RevisionModel.create(
            app: app,
            version: next_version,
            droplet_guid: app.droplet_guid,
            environment_variables: app.environment_variables
          )

          newest_unique_processes_for_app(app).
            select { |p| p.command.present? }.
            each   { |p| revision.add_command_for_process_type(p.type, p.command) }

          record_audit_event(revision, user_audit_info)

          revision
        end
      end

      private

      def newest_unique_processes_for_app(app)
        app.processes_dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).uniq(&:type)
      end

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
