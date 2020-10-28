module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete
      class UnprocessableDelete < StandardError; end

      class ConcurrencyError < StandardError; end

      RequiresAsync = Class.new.freeze

      DeleteStatus = Struct.new(:finished, :operation).freeze
      DeleteStarted = ->(operation) { DeleteStatus.new(false, operation) }
      DeleteComplete = DeleteStatus.new(true, nil).freeze

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def delete(binding, async_allowed:)

        return RequiresAsync.new unless async_allowed || binding.service_instance.user_provided_instance?

        result = send_unbind_to_broker(binding)
        if result[:finished]
          perform_delete_actions(binding)
        else
          update_last_operation(binding, operation: result[:operation])
        end

        return result
      rescue => e
        unless e.is_a? ConcurrencyError
          update_last_operation(binding, state: 'failed', description: e.message)
        end

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.fetch_and_handle_service_binding_last_operation(binding)
        case details[:last_operation][:state]
        when 'in progress'
          update_last_operation(
            binding,
            description: details[:last_operation][:description],
            operation: binding.last_operation.broker_provided_operation)
          return ContinuePolling.call(details[:retry_after])
        when 'succeeded'
          perform_delete_actions(binding)
          return PollingFinished
        when 'failed'
          update_last_operation(binding, state: 'failed', description: details[:last_operation][:description])
          raise LastOperationFailedState
        end
      rescue LastOperationFailedState => e
        raise e
      rescue => e
        update_last_operation(binding, state: 'failed', description: e.message)
        raise e
      end

      private

      attr_reader :service_event_repository

      def send_unbind_to_broker(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.unbind(binding, nil, true)
        details[:async] ? DeleteStarted.call(details[:operation]) : DeleteComplete
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ConcurrencyError
        raise ConcurrencyError.new(
          'The service broker rejected the request due to an operation being in progress for the service route binding'
        )
      rescue => err
        raise UnprocessableDelete.new("Service broker failed to delete service binding for instance #{binding.service_instance.name}: #{err.message}")
      end

      def perform_delete_actions(binding)
        record_audit_event(binding)
        binding.destroy
        binding.notify_diego
      end

      def record_audit_event(binding)
        service_event_repository.record_service_instance_event(
          :unbind_route,
          binding.service_instance,
          { route_guid: binding.route.guid },
        )
      end

      def update_last_operation(binding, description: nil, state: 'in progress', operation: nil)
        binding.save_with_new_operation({}, {
          type: 'delete',
          state: state,
          description: description,
          broker_provided_operation: operation || binding.last_operation.broker_provided_operation
        })
      end
    end
  end
end
