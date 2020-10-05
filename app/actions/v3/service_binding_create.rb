require 'services/service_brokers/service_client_provider'

module VCAP::CloudController
  module V3
    class ServiceBindingCreate

      def bind(precursor, parameters: {}, accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: precursor.service_instance)
        details = client.bind(precursor, arbitrary_parameters: parameters, accepts_incomplete: accepts_incomplete)

        if details[:async]
          not_retrievable! unless bindings_retrievable?(precursor)
          save_incomplete_binding(precursor, details[:operation])
        else
          complete_binding_and_save(precursor, details)
        end
      rescue => e
        precursor.save_with_attributes_and_new_operation(
          {},
          {
          type: 'create',
          state: 'failed',
          description: e.message,
        })

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = fetch_last_operation(client, binding)
        return { finished: false } unless details

        attributes = {}

        complete = details[:last_operation][:state] == 'succeeded'
        if complete
          params = client.fetch_service_binding(binding)
          attributes[:route_service_url] = params[:route_service_url]
        end

        binding.save_with_new_operation(
          attributes,
          {
            type: 'create',
            state: details[:last_operation][:state],
            description: details[:last_operation][:description],
          }
        )

        if complete
          binding.notify_diego
          record_audit_event(binding)
        end

        if binding.reload.terminal_state?
          { finished: true }
        else
          { finished: false, retry_after: details[:retry_after] }
        end
      rescue => e
        binding.save_with_new_operation({}, {
          type: 'create',
          state: 'failed',
          description: e.message,
        })
        { finished: true }
      end

      class BindingNotRetrievable < StandardError; end

      private

      def save_incomplete_binding(precursor, operation)
        precursor.save_with_new_operation({},
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
        binding.save_with_new_operation({}, {
          type: 'create',
          state: 'in progress',
          description: e.message,
        })

        return nil
      end
    end
  end
end
