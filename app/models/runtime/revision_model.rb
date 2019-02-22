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
      process_commands.map { |p| [p.process_type, p.process_command] }.to_h
    end

  end
end
