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
        if message.requested?(:authentication)
          params[:auth_username] = message.username
          params[:auth_password] = message.password
        end

        if broker.in_transitional_state?
          raise InvalidServiceBroker.new('Cannot update a broker when other operation is already in progress')
        end

        pollable_job = nil
        ServiceBroker.db.transaction do
          broker.update(params)

          if broker.service_broker_state
            broker.service_broker_state.update(state: ServiceBrokerStateEnum::SYNCHRONIZING)
          else
            ServiceBrokerState.create(
              service_broker_id: broker.id,
              state: ServiceBrokerStateEnum::SYNCHRONIZING
            )
          end

          service_event_repository.record_broker_event_with_request(:update, broker, message.audit_hash)

          synchronization_job = SynchronizeBrokerCatalogJob.new(broker.guid)
          pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: Jobs::Queues.generic).enqueue_pollable
        end

        { pollable_job: pollable_job }
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceBroker.new(e.errors.full_messages.join(','))
      end
    end
  end
end
