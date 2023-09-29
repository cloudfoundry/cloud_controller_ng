require 'actions/services/mixins/service_broker_registration_error_parser'
module VCAP::CloudController
  class ServiceBrokerUpdate
    include VCAP::CloudController::ServiceBrokerRegistrationErrorParser

    def initialize(service_manager, services_event_repository, warning_observer, route_services_enabled, volume_services_enabled)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @warning_observer = warning_observer
      @route_services_enabled = route_services_enabled
      @volume_services_enabled = volume_services_enabled
    end

    def update(guid, params)
      broker = ServiceBroker.find(guid:)
      return nil unless broker

      ServiceBroker.db.transaction do
        old_broker = broker.clone
        broker.set(params)
        registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(
          broker,
          @service_manager,
          @services_event_repository,
          @route_services_enabled,
          @volume_services_enabled
        )

        raise get_exception_from_errors(registration) unless registration.update

        @services_event_repository.record_broker_event(:update, old_broker, params)

        registration.warnings.each { |warning| @warning_observer.add_warning(warning) } unless registration.warnings.empty?
      end

      broker
    end
  end
end
