module VCAP::CloudController
  class RoutePolicyLabelModel < Sequel::Model(:route_policy_labels)
    many_to_one :route_policy,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
