require 'jobs/v3/services/synchronize_broker_catalog_job'

module VCAP::CloudController
  module V3
    class ServiceBrokerCreate
      class InvalidServiceBroker < StandardError
      end

      class SpaceNotFound < StandardError
      end

      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def create(message)
        params = {
          name: message.name,
          broker_url: message.url,
          auth_username: message.username,
          auth_password: message.password,
          space_guid: message.relationships_message.space_guid,
          state: ServiceBrokerStateEnum::SYNCHRONIZING
        }

        pollable_job = nil
        ServiceBroker.db.transaction do
          broker = ServiceBroker.create(params)
          MetadataUpdate.update(broker, message)

          service_event_repository.record_broker_event_with_request(:create, broker, message.audit_hash)

          synchronization_job = SynchronizeBrokerCatalogJob.new(broker.guid, user_audit_info: service_event_repository.user_audit_info)
          pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: Jobs::Queues.generic).enqueue_pollable
        end

        { pollable_job: pollable_job }
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceBroker.new(e.errors.full_messages.join(','))
      end

      private

      attr_reader :service_event_repository

      def route_services_enabled?
        VCAP::CloudController::Config.config.get(:route_services_enabled)
      end

      def volume_services_enabled?
        VCAP::CloudController::Config.config.get(:volume_services_enabled)
      end
    end
  end
end
