module VCAP::CloudController
  class DropletAnnotationModel < Sequel::Model(:droplet_annotations)
    many_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
