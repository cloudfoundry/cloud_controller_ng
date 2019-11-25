require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class KpackLifecycleDataModel < Sequel::Model(:kpack_lifecycle_data)
    LIFECYCLE_TYPE = Lifecycles::KPACK

    many_to_one :droplet,
      class: '::VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :build,
      class: '::VCAP::CloudController::BuildModel',
      key: :build_guid,
      primary_key: :guid,
      without_guid_generation: true
  end
end
