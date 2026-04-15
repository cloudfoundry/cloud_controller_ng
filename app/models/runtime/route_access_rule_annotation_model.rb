module VCAP::CloudController
  class RouteAccessRuleAnnotationModel < Sequel::Model(:route_access_rule_annotations)
    set_primary_key :id
    many_to_one :route_access_rule,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
