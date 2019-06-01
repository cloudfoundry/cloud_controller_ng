module VCAP::CloudController
  class RouteLabelModel < Sequel::Model(:route_labels)
    many_to_one :route,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
