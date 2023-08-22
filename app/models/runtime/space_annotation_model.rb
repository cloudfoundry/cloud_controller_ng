module VCAP::CloudController
  class SpaceAnnotationModel < Sequel::Model(:space_annotations_migration_view)
    set_primary_key :id
    many_to_one :space,
                class: 'VCAP::CloudController::Space',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
