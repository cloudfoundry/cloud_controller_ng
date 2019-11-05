module VCAP::CloudController
  class ServiceBrokerUpdateRequest < Sequel::Model
    one_to_one :service_broker
    set_field_as_encrypted :authentication
  end
end
