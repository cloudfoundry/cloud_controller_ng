require 'controllers/services/lifecycle/broker_instance_helper'

module VCAP::CloudController
  class BrokerInstanceProvisioner
    def initialize(service_manager, services_event_repository, access_validator, warning_observer)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @warning_observer = warning_observer
    end

    def create_broker_instance(params)
      @access_validator.validate_access(:create, ServiceBroker)

      broker = ServiceBroker.new(params)

      registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(broker, @service_manager, @services_event_repository)
      unless registration.create
        raise BrokerInstanceHelper.get_exception_from_errors(registration)
      end

      @services_event_repository.record_broker_event(:create, broker, params)

      if !registration.warnings.empty?
        registration.warnings.each { |warning| @warning_observer.add_warning(warning) }
      end

      broker
    end
  end
end
