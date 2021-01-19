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

      # Technically a name change can be done without contacting the broker. However the CF CLI v7.2
      # (which is the most recent version at the time of writing) expects a broker rename to return a job.
      # Once CF CLI v7.2 is out of support, then it may make sense to allow name changes to happen
      # synchronously.
      def update_broker_needed?
        message.requested?(:url) || message.requested?(:authentication) || message.requested?(:name)
      end

      def update_sync
        ServiceBroker.db.transaction do
          MetadataUpdate.update(broker, message)
        end
      end

      def enqueue_update
        params = {}
        params[:broker_url] = message.url if message.requested?(:url)
        params[:authentication] = message.authentication.to_json if message.requested?(:authentication)
        params[:service_broker_id] = broker.id

        if message.requested?(:name)
          unique_name! if ServiceBroker.where(name: message.name).exclude(guid: broker.guid).any?
          params[:name] = message.name
        end

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

          synchronization_job = UpdateBrokerJob.new(
            update_request.guid,
            broker.guid,
            previous_broker_state,
            user_audit_info: service_event_repository.user_audit_info
          )
          pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: Jobs::Queues.generic).enqueue_pollable
        end

        pollable_job
      end

      private

      attr_reader :broker, :service_event_repository, :message

      def unique_name!
        raise InvalidServiceBroker.new('Name must be unique')
      end
    end
  end
end
