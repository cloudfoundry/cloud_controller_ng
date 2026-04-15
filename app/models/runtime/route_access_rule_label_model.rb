module VCAP::CloudController
  class RouteAccessRuleLabelModel < Sequel::Model(:route_access_rule_labels)
    many_to_one :route_access_rule,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
