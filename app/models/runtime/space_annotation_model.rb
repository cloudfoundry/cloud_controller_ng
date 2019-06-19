module VCAP::CloudController
  class SpaceAnnotationModel < Sequel::Model(:space_annotations)
    many_to_one :space,
                class: 'VCAP::CloudController::Space',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
