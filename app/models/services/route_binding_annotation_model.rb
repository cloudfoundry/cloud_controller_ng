module VCAP::CloudController
  class RouteBindingAnnotationModel < Sequel::Model(:route_binding_annotations)
    many_to_one :route_binding,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
