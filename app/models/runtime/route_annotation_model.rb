module VCAP::CloudController
  class RouteAnnotationModel < Sequel::Model(:route_annotations)
    many_to_one :route,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
