module VCAP::CloudController
  class ServiceBrokerUpdateRequestAnnotationModel < Sequel::Model(:service_broker_update_request_annotations)
    many_to_one :service_broker_update_request,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
