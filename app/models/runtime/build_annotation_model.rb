module VCAP::CloudController
  class BuildAnnotationModel < Sequel::Model(:build_annotations)
    many_to_one :build,
                class: 'VCAP::CloudController::BuildModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
