module VCAP::CloudController
  class BuildLabelModel < Sequel::Model(:build_labels)
    many_to_one :build,
      class: 'VCAP::CloudController::BuildModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
