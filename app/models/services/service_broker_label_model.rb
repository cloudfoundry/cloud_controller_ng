module VCAP::CloudController
  class ServiceBrokerLabelModel < Sequel::Model(:service_broker_labels)
    many_to_one :service_broker,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
