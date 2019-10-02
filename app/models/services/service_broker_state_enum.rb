module VCAP::CloudController
  class ServiceBrokerStateEnum
    SYNCHRONIZING = 'SYNCHRONIZING'.freeze
    SYNCHRONIZATION_FAILED = 'SYNCHRONIZATION_FAILED'.freeze
    AVAILABLE = 'AVAILABLE'.freeze
    DELETE_IN_PROGRESS = 'DELETE_IN_PROGRESS'.freeze
    DELETE_FAILED = 'DELETE_FAILED'.freeze
  end
end
