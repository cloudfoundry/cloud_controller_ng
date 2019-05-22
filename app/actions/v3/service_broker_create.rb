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
          true, # TODO: get it from config
          true, # TODO: get it from config
        )

        registration.create
      end

      private

      attr_reader :service_event_repository, :service_manager
    end
  end
end
