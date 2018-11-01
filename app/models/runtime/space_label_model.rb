module VCAP::CloudController
  class SpaceLabelModel < Sequel::Model(:space_labels)
    many_to_one :space,
      class: 'VCAP::CloudController::Space',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
