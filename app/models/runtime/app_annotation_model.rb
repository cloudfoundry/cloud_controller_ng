module VCAP::CloudController
  class AppAnnotationModel < Sequel::Model(:app_annotations)
    many_to_one :app,
      class: 'VCAP::CloudController::AppModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
