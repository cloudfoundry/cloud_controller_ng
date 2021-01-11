require 'jobs/v3/services/update_broker_job'
require 'actions/metadata_update'
require 'jobs/enqueuer'
require 'jobs/queues'

module VCAP::CloudController
  module V3
    class ServiceBrokerUpdate
      class InvalidServiceBroker < StandardError
      end

      def initialize(service_broker, message, service_event_repository)
        @broker = service_broker
        @message = message
        @service_event_repository = service_event_repository
      end

      def update_broker_needed?
        message.requested?(:url) || message.requested?(:authentication)
      end

      def update_sync
        ServiceBroker.db.transaction do
          broker.update(process_name(message))
          MetadataUpdate.update(broker, message)
        end
      end

      def enqueue_update
        params = process_name(message)
        params[:broker_url] = message.url if message.requested?(:url)
        params[:authentication] = message.authentication.to_json if message.requested?(:authentication)
        params[:service_broker_id] = broker.id

        if broker.in_transitional_state?
          raise InvalidServiceBroker.new('Cannot update a broker when other operation is already in progress')
        end

        pollable_job = nil
        previous_broker_state = broker.state
        ServiceBrokerUpdateRequest.db.transaction do
          broker.update(state: ServiceBrokerStateEnum::SYNCHRONIZING)

          update_request = ServiceBrokerUpdateRequest.create(params)
          MetadataUpdate.update(update_request, message, destroy_nil: false)

          service_event_repository.record_broker_event_with_request(:update, broker, message.audit_hash)

          synchronization_job = UpdateBrokerJob.new(update_request.guid, broker.guid, previous_broker_state)
          pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: Jobs::Queues.generic).enqueue_pollable
        end

        pollable_job
      end

      private

      attr_reader :broker, :service_event_repository, :message

      def process_name(message)
        params = {}
        if message.requested?(:name)
          unique_name! if ServiceBroker.where(name: message.name).exclude(guid: broker.guid).any?
          params[:name] = message.name
        end

        params
      end

      def unique_name!
        raise InvalidServiceBroker.new('Name must be unique')
      end
    end
  end
end
