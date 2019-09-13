require 'jobs/v3/synchronize_broker_catalog_job'

module VCAP::CloudController
  module V3
    class ServiceBrokerCreate
      class InvalidServiceBroker < StandardError
      end

      class SpaceNotFound < StandardError
      end

      def initialize(service_event_repository, service_manager)
        @service_event_repository = service_event_repository
        @service_manager = service_manager
      end

      def create(message)
        params = {
          name: message.name,
          broker_url: message.url,
          auth_username: message.credentials_data.username,
          auth_password: message.credentials_data.password,
          space_guid: message.relationships_message.space_guid
        }
        broker = ServiceBroker.create(params)

        broker.update(
          service_broker_state: VCAP::CloudController::ServiceBrokerState.new(
            state: VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING
          )
        )

        service_event_repository.record_broker_event(:create, broker, params)

        synchronization_job = SynchronizeBrokerCatalogJob.new(broker.guid)
        pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: 'cc-generic').enqueue_pollable

        { pollable_job: pollable_job }
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceBroker.new(e.errors.full_messages.join(','))
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
