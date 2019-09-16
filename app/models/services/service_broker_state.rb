module VCAP::CloudController
  class ServiceBrokerState < Sequel::Model
    import_attributes :state, :service_broker_guid
    export_attributes :guid, :state, :service_broker_guid
  end
end
