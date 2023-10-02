module VCAP::CloudController
  class ServiceKeyAnnotationModel < Sequel::Model(:service_key_annotations_migration_view)
    set_primary_key :id
    many_to_one :service_key,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
