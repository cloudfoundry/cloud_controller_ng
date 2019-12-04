module VCAP::CloudController
  class ServiceBrokerUpdateRequestLabelModel < Sequel::Model(:service_broker_update_request_labels)
    many_to_one :service_broker_update_request,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
