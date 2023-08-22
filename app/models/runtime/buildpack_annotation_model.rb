module VCAP::CloudController
  class BuildpackAnnotationModel < Sequel::Model(:buildpack_annotations)
    set_primary_key :id
    many_to_one :buildpack,
                class: 'VCAP::CloudController::BuildpackModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
