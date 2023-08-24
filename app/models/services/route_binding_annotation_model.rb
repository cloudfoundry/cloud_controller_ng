module VCAP::CloudController
  class RouteBindingAnnotationModel < Sequel::Model(:route_binding_annotations_migration_view)
    set_primary_key :id
    many_to_one :route_binding,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
    include MetadataModelMixin
  end
end
