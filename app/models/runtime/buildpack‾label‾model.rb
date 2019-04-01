module VCAP::CloudController
  class BuildpackLabelModel < Sequel::Model(:buildpack_labels)
    many_to_one :buildpack,
      class: 'VCAP::CloudController::Buildpack',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
