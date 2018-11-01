module VCAP::CloudController
  class SpaceLabelModel < Sequel::Model(:space_labels)
    RESOURCE_GUID_COLUMN = :space_guid
    many_to_one :space,
      class: 'VCAP::CloudController::Space',
      primary_key: :guid,
      key: :space_guid,
      without_guid_generation: true
  end
end
