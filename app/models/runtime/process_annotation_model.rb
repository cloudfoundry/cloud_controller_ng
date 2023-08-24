module VCAP::CloudController
  class ProcessAnnotationModel < Sequel::Model(:process_annotations_migration_view)
    set_primary_key :id
    many_to_one :process,
                class: 'VCAP::CloudController::ProcessModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
