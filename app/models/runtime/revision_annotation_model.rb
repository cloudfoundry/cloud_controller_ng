module VCAP::CloudController
  class RevisionAnnotationModel < Sequel::Model(:revision_annotations)
    many_to_one :revision,
      class: 'VCAP::CloudController::RevisionModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
