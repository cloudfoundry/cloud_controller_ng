require 'services/service_brokers/service_client_provider'

module VCAP::CloudController
  module V3
    class ServiceBindingDelete
      class UnprocessableDelete < StandardError; end

      class ConcurrencyError < StandardError; end

      class OperationCancelled < StandardError; end

      DeleteStatus = Struct.new(:finished, :operation).freeze
      DeleteStarted = ->(operation) { DeleteStatus.new(false, operation) }
      DeleteComplete = DeleteStatus.new(true, nil).freeze

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      def blocking_operation_in_progress?(binding)
        binding.operation_in_progress? &&
          (binding.create_initial? || binding.delete_in_progress?)
      end

      def delete(binding)
        operation_in_progress! if blocking_operation_in_progress?(binding)

        result = send_unbind_to_client(binding)
        if result[:finished]
          perform_delete_actions(binding)
        else
          perform_start_delete_actions(binding)
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
        details = client.fetch_and_handle_service_binding_last_operation(binding, user_guid: @user_audit_info.user_guid)

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

      def send_unbind_to_client(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.unbind(
          binding,
          accepts_incomplete: true,
          user_guid: @user_audit_info.user_guid
        )
        details[:async] ? DeleteStarted.call(details[:operation]) : DeleteComplete
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ConcurrencyError
        broker_concurrency_error!
      rescue CloudController::Errors::ApiError => err
        broker_concurrency_error! if err.name == 'AsyncServiceBindingOperationInProgress'
        unprocessable!(binding, err)
      rescue => err
        unprocessable!(binding, err)
      end

      def update_last_operation(binding, description: nil, state: 'in progress', operation: nil)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'delete',
            state: state,
            description: description,
            broker_provided_operation: operation || binding.last_operation&.broker_provided_operation
          })
      end

      def unprocessable!(binding, err)
        raise UnprocessableDelete.new("Service broker failed to delete service binding for instance #{binding.service_instance.name}: #{err.message}")
      end

      def operation_in_progress!
        raise ConcurrencyError.new('The delete request was rejected due to an operation being in progress for the service binding.')
      end

      def broker_concurrency_error!
        raise ConcurrencyError.new(
          'The service broker rejected the request due to an operation being in progress for the service binding.'
        )
      end
    end
  end
end
