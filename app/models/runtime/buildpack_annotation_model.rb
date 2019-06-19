module VCAP::CloudController
  class BuildpackAnnotationModel < Sequel::Model(:buildpack_annotations)
    many_to_one :buildpack,
                class: 'VCAP::CloudController::BuildpackModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
