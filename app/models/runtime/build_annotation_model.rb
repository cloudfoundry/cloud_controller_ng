module VCAP::CloudController
  class BuildAnnotationModel < Sequel::Model(:build_annotations)
    set_primary_key :id
    many_to_one :build,
                class: 'VCAP::CloudController::BuildModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
