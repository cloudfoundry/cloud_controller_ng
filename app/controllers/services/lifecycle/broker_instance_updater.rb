require 'controllers/services/lifecycle/broker_instance_helper'

module VCAP::CloudController
  class BrokerInstanceUpdater
    def initialize(service_manager, services_event_repository, access_validator, warning_observer)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @warning_observer = warning_observer
    end

    def update_broker_instance(guid, params)
      @access_validator.validate_access(:update, ServiceBroker)

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
