module VCAP::CloudController
  class AppAnnotationModel < Sequel::Model(:app_annotations_migration_view)
    set_primary_key :id
    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
