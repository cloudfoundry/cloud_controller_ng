require 'actions/revision_create'

module VCAP::CloudController
  class RevisionResolver
    class NoUpdateRollback < StandardError; end
    class << self
      def update_app_revision(app, user_audit_info)
        return nil unless app.revisions_enabled && app.droplet_guid.present?

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

        reasons = revision_reasons(latest_revision, app)
        if reasons.empty?
          latest_revision
        else
          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: app.environment_variables,
            description: formatted_revision_reasons(reasons),
            commands_by_process_type: app.commands_by_process_type,
            user_audit_info: user_audit_info,
          )
        end
      end

      def rollback_app_revision(app, revision, user_audit_info)
        return nil unless app.revisions_enabled

        reasons = revision_reasons(app.latest_revision, revision)
        if reasons.empty?
          raise NoUpdateRollback.new('Unable to rollback. The code and configuration you are rolling back to is the same as the deployed revision.')
        end

        reasons.push("Rolled back to revision #{revision.version}.")

        RevisionCreate.create(
          app: app,
          droplet_guid: revision.droplet_guid,
          environment_variables: revision.environment_variables,
          description: formatted_revision_reasons(reasons),
          commands_by_process_type: revision.commands_by_process_type,
          user_audit_info: user_audit_info,
        )
      end

      private

      def revision_reasons(latest_revision, revision_to_create)
        reasons = []

        if latest_revision.droplet_guid != revision_to_create.droplet_guid
          reasons.push('New droplet deployed.')
        end

        if latest_revision.environment_variables != revision_to_create.environment_variables
          reasons.push('New environment variables deployed.')
        end

        reasons.push(*list_process_command_changes(
          latest_revision.commands_by_process_type,
          revision_to_create.commands_by_process_type
        ))

        sidecars_differences = Hashdiff.diff(
          latest_revision.sidecars.sort_by(&:name).map(&:to_hash),
          revision_to_create.sidecars.sort_by(&:name).map(&:to_hash)
        )

        reasons << 'Sidecars updated.' if sidecars_differences.present?

        reasons.sort
      end

      def formatted_revision_reasons(reasons)
        reasons.join(' ')
      end

      def list_process_command_changes(commands_by_process_type_a, commands_by_process_type_b)
        commands_differences = Hashdiff.diff(commands_by_process_type_a, commands_by_process_type_b)

        commands_differences.map do |change_type, process_type, *command_change|
          if change_type == '+'
            "New process type '#{process_type}' added."
          elsif change_type == '-'
            "Process type '#{process_type}' removed."
          elsif command_change[0].nil?
            "Custom start command added for '#{process_type}' process."
          elsif command_change[1].nil?
            "Custom start command removed for '#{process_type}' process."
          else
            "Custom start command updated for '#{process_type}' process."
          end
        end
      end
    end
  end
end
