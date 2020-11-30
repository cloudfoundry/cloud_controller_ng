require 'services/service_brokers/service_client_provider'

module VCAP::CloudController
  module V3
    class LastOperationFailedState < StandardError
    end

    class ServiceBindingCreate
      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }

      def bind(binding, parameters: {}, accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.bind(binding, arbitrary_parameters: parameters, accepts_incomplete: accepts_incomplete)

        if details[:async]
          not_retrievable! unless bindings_retrievable?(binding)
          save_incomplete_binding(binding, details[:operation])
        else
          complete_binding_and_save(binding, details[:binding], { state: 'succeeded' })
        end
      rescue => e
        save_failed_state(binding, e)

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.fetch_and_handle_service_binding_last_operation(binding)

        case details[:last_operation][:state]
        when 'succeeded'
          params = client.fetch_service_binding(binding)
          complete_binding_and_save(binding, params, details[:last_operation])
          return PollingFinished
        when 'in progress'
          save_last_operation(binding, details)
          ContinuePolling.call(details[:retry_after])
        when 'failed'
          save_last_operation(binding, details)
          raise LastOperationFailedState
        end
      rescue LastOperationFailedState => e
        raise e
      rescue => e
        save_failed_state(binding, e)
        raise e
      end

      class BindingNotRetrievable < StandardError; end

      private

      def save_failed_state(binding, e)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'failed',
            description: e.message,
          }
        )
      end

      def complete_binding_and_save(binding, binding_details, last_operation)
        binding.save_with_attributes_and_new_operation(
          binding_details.symbolize_keys.slice(*permitted_binding_attributes),
          {
            type: 'create',
            state: last_operation[:state],
            description: last_operation[:description],
          }
        )

        notify(binding)

        event_repository.record_create(
          binding,
          @user_audit_info,
          @audit_hash,
          manifest_triggered: false
        )
      end

      def save_last_operation(binding, details)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: details[:last_operation][:state],
            description: details[:last_operation][:description],
            broker_provided_operation: binding.last_operation.broker_provided_operation
          }
        )
      end

      def save_incomplete_binding(binding, broker_operation)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'in progress',
            broker_provided_operation: broker_operation
          }
        )
        event_repository.record_start_create(binding, @user_audit_info, @audit_hash, manifest_triggered: false)
      end

      def notify(binding); end

      def bindings_retrievable?(binding)
        binding.service_instance.service.bindings_retrievable
      end

      def not_retrievable!
        raise BindingNotRetrievable.new('The broker responded asynchronously but does not support fetching binding data')
      end
    end
  end
end
