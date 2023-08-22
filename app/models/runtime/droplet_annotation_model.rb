module VCAP::CloudController
  class DropletAnnotationModel < Sequel::Model(:droplet_annotations)
    set_primary_key :id
    many_to_one :droplet,
                class: 'VCAP::CloudController::DropletModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
