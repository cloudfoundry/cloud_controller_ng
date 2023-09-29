module VCAP::CloudController
  class ServiceBrokerUpdateRequestAnnotationModel < Sequel::Model(:service_broker_update_request_annotations_migration_view)
    set_primary_key :id
    many_to_one :service_broker_update_request,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
