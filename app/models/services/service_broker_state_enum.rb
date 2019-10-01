module VCAP::CloudController
  class ServiceBrokerStateEnum
    SYNCHRONIZING = 'SYNCHRONIZING'.freeze
    SYNCHRONIZATION_FAILED = 'SYNCHRONIZATION_FAILED'.freeze
    AVAILABLE = 'AVAILABLE'.freeze
    DELETE_IN_PROGRESS = 'DELETE IN PROGRESS'.freeze
  end
end
