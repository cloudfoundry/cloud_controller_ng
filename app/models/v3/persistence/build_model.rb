module VCAP::CloudController
  class BuildModel < Sequel::Model
    one_to_one :droplet,
      class:       'VCAP::CloudController::DropletModel',
      key:         :build_guid,
      primary_key: :guid
  end
end
