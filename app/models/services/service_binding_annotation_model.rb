module VCAP::CloudController
  class ServiceBindingAnnotationModel < Sequel::Model(:service_binding_annotations)
    many_to_one :service_binding,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
