require 'controllers/services/lifecycle/broker_instance_helper'

module VCAP::CloudController
  class ServiceBrokerUpdate
    def initialize(service_manager, services_event_repository, warning_observer)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @warning_observer = warning_observer
    end

    def update(guid, params)
      broker = ServiceBroker.find(guid: guid)
      return nil unless broker

      ServiceBroker.db.transaction do
        old_broker = broker.clone
        broker.set(params)
        registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(broker, @service_manager, @services_event_repository)

        unless registration.update
          raise BrokerInstanceHelper.get_exception_from_errors(registration)
        end

        @services_event_repository.record_broker_event(:update, old_broker, params)

        if !registration.warnings.empty?
          registration.warnings.each { |warning| @warning_observer.add_warning(warning) }
        end
      end

      broker
    end
  end
end
