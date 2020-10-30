module VCAP::CloudController
  class RouteBindingLabelModel < Sequel::Model(:route_binding_labels)
    many_to_one :route_binding,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
