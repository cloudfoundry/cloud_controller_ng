module VCAP::CloudController
  class DropletLabelModel < Sequel::Model(:droplet_labels)
    many_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
