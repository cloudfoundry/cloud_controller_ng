module VCAP::CloudController
  class RevisionProcessCommandModel < Sequel::Model(:revision_process_commands)
    many_to_one :revision,
      class: 'VCAP::CloudController::RevisionModel',
      primary_key: :guid,
      key: :revision_guid,
      without_guid_generation: true
  end
end
