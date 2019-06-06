module VCAP::CloudController
  module V3
    class ServiceBrokerCreate
      def initialize(service_event_repository, service_manager)
        @service_event_repository = service_event_repository
        @service_manager = service_manager
      end

      def create(credentials)
        broker = VCAP::CloudController::ServiceBroker.create(
          name: credentials[:name],
          broker_url: credentials[:url],
          auth_username: credentials[:username],
          auth_password: credentials[:password],
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
