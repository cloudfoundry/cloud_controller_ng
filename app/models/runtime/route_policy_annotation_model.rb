module VCAP::CloudController
  class RoutePolicyAnnotationModel < Sequel::Model(:route_policy_annotations)
    set_primary_key :id
    many_to_one :route_policy,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
