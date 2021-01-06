module VCAP::CloudController
  class ServiceKeyAnnotationModel < Sequel::Model(:service_key_annotations)
    many_to_one :service_key,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
