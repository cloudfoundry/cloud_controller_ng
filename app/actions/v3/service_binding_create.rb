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
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'failed',
            description: e.message,
          }
        )

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = fetch_last_operation(client, binding)
        return ContinuePolling.call(nil) unless details

        if details[:last_operation][:state] == 'succeeded'
          params = client.fetch_service_binding(binding)
          complete_binding_and_save(binding, params, details[:last_operation])
          return PollingFinished
        end

        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: details[:last_operation][:state],
            description: details[:last_operation][:description],
          }
        )

        if details[:last_operation][:state] == 'failed'
          raise LastOperationFailedState.new(details[:last_operation][:description])
        end

        if binding.reload.terminal_state?
          PollingFinished
        else
          ContinuePolling.call(details[:retry_after])
        end
      rescue => e
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'failed',
            description: e.message,
          }
        )
        raise e
      end

      class BindingNotRetrievable < StandardError; end

      private

      def save_incomplete_binding(precursor, operation)
        precursor.save_with_attributes_and_new_operation(
          {},
          {
            type: 'create',
            state: 'in progress',
            broker_provided_operation: operation
          }
        )
      end

      def bindings_retrievable?(binding)
        binding.service_instance.service.bindings_retrievable
      end

      def not_retrievable!
        raise BindingNotRetrievable.new('The broker responded asynchronously but does not support fetching binding data')
      end

      def fetch_last_operation(client, binding)
        client.fetch_service_binding_last_operation(binding)
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse,
             VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerRequestRejected,
             HttpRequestError => e
        binding.save_with_attributes_and_new_operation(
          {},
          {
          type: 'create',
          state: 'in progress',
          description: e.message,
        })

        return nil
      end
    end
  end
end
