require 'jobs/v3/services/update_broker_job'

module VCAP::CloudController
  module V3
    class ServiceBrokerUpdate
      class InvalidServiceBroker < StandardError
      end

      attr_reader :broker, :service_event_repository

      def initialize(service_broker, service_event_repository)
        @broker = service_broker
        @service_event_repository = service_event_repository
      end

      def update(message)
        params = {}
        params[:name] = message.name if message.requested?(:name)
        params[:broker_url] = message.url if message.requested?(:url)
        params[:authentication] = message.authentication.to_json if message.requested?(:authentication)
        params[:service_broker_id] = broker.id

        if params[:name] && !ServiceBroker.where(name: params[:name]).exclude(guid: broker.guid).empty?
          raise InvalidServiceBroker.new('Name must be unique')
        end

        if broker.in_transitional_state?
          raise InvalidServiceBroker.new('Cannot update a broker when other operation is already in progress')
        end

        pollable_job = nil
        previous_broker_state = broker.state
        ServiceBrokerUpdateRequest.db.transaction do
          broker.update(state: ServiceBrokerStateEnum::SYNCHRONIZING)

          update_request = ServiceBrokerUpdateRequest.create(params)
          MetadataUpdate.update(update_request, message)

          service_event_repository.record_broker_event_with_request(:update, broker, message.audit_hash)

          synchronization_job = UpdateBrokerJob.new(update_request.guid, broker.guid, previous_broker_state)
          pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: Jobs::Queues.generic).enqueue_pollable
        end

        { pollable_job: pollable_job }
      end
    end
  end
end
