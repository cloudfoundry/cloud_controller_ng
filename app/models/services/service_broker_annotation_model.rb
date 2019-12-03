module VCAP::CloudController
  class ServiceBrokerAnnotationModel < Sequel::Model(:service_broker_annotations)
    many_to_one :service_broker,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
