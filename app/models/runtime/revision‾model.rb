module VCAP::CloudController
  class RevisionModel < Sequel::Model(:revisions)
    include Serializer

    many_to_one :app,
      class: '::VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :droplet,
      class:             '::VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :labels,
      class: 'VCAP::CloudController::RevisionLabelModel',
      key: :resource_guid,
      primary_key: :guid

    one_to_many :annotations,
      class: 'VCAP::CloudController::RevisionAnnotationModel',
      key: :resource_guid,
      primary_key: :guid

    one_to_many :process_commands,
      class: 'VCAP::CloudController::RevisionProcessCommandModel',
      key: :revision_guid,
      primary_key: :guid

    set_field_as_encrypted :environment_variables, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    def add_command_for_process_type(type, command)
      add_process_command(process_type: type, process_command: command)
    end

    def commands_by_process_type
      return {} unless droplet&.process_types # Unsure if this case ever actually happens outside of specs

      # revision_process_commands are not created when the process has not changed from the
      # droplet's original process_command (would just be storing a NULL for command), so go to
      # droplet to get all process command types
      droplet.process_types.keys.
        map { |k| [k, process_commands_dataset.first(process_type: k)&.process_command] }.to_h
    end

    def out_of_date_reasons
      reasons = []

      if droplet_guid != app.droplet_guid
        reasons.push('New droplet deployed.')
      end

      if environment_variables != app.environment_variables
        reasons.push('New environment variables deployed.')
      end

      commands_differences = HashDiff.diff(commands_by_process_type, app.commands_by_process_type)

      reasons.push(*commands_differences.map do |change_type, process_type, *command_change|
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
      )

      reasons.sort
    end
  end
end
