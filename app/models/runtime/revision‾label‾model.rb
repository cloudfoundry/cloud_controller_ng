module VCAP::CloudController
  class RevisionLabelModel < Sequel::Model(:revision_labels)
    many_to_one :revision,
      class: 'VCAP::CloudController::RevisionModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
