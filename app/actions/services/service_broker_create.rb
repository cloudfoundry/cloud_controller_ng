require 'actions/services/mixins/service_broker_registration_error_parser'

module VCAP::CloudController
  class ServiceBrokerCreate
    include ServiceBrokerRegistrationErrorParser

    def initialize(service_manager, services_event_repository, warning_observer)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @warning_observer = warning_observer
    end

    def create(params)
      broker = ServiceBroker.new(params)

      registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(broker, @service_manager, @services_event_repository)
      unless registration.create
        raise get_exception_from_errors(registration)
      end

      @services_event_repository.record_broker_event(:create, broker, params)

      if !registration.warnings.empty?
        registration.warnings.each { |warning| @warning_observer.add_warning(warning) }
      end

      broker
    end
  end
end
