module VCAP::CloudController
  module V3
    class ServiceBrokerCreate
      def initialize(service_event_repository, service_manager)
        @service_event_repository = service_event_repository
        @service_manager = service_manager
      end

      def create(message)
        broker = VCAP::CloudController::ServiceBroker.new(
          name: message.name,
          broker_url: message.url,
          auth_username: message.credentials_data.username,
          auth_password: message.credentials_data.password,
        )

        registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(
          broker,
          service_manager,
          service_event_repository,
          route_services_enabled?,
          volume_services_enabled?,
        )

        registration.create

        {
          warnings: registration.warnings
        }
      end

      private

      attr_reader :service_event_repository, :service_manager

      def route_services_enabled?
        VCAP::CloudController::Config.config.get(:route_services_enabled)
      end

      def volume_services_enabled?
        VCAP::CloudController::Config.config.get(:volume_services_enabled)
      end
    end
  end
end
