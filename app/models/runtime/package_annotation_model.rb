module VCAP::CloudController
  class PackageAnnotationModel < Sequel::Model(:package_annotations)
    set_primary_key :id
    many_to_one :package,
                class: 'VCAP::CloudController::PackageModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
