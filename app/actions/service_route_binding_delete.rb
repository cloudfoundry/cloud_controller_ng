module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete
      class UnprocessableDelete < StandardError; end

      RequiresAsync = Class.new.freeze
      DeleteComplete = Class.new.freeze
      DeleteStarted = Struct.new(:operation).freeze
      DeleteInProgress = Struct.new(:retry_after).freeze

      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def delete(binding, async_allowed:)
        return RequiresAsync.new unless async_allowed || binding.service_instance.user_provided_instance?

        operation_in_progress! if binding.service_instance.operation_in_progress?

        result = send_unbind_to_broker(binding)
        case result
        when DeleteStarted
          update_last_operation(binding, operation: result[:operation])
        when DeleteComplete
          perform_delete_actions(binding)
        end

        result
      rescue => e
        update_last_operation(binding, state: 'failed', description: e.message)

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.fetch_service_binding_last_operation(binding)
        case details[:last_operation][:state]
        when 'in progress'
          update_last_operation(binding, description: details[:last_operation][:description])
          DeleteInProgress.new(details[:retry_after])
        when 'succeeded'
          perform_delete_actions(binding)
          DeleteComplete.new
        when 'failed'
          update_last_operation(binding, state: 'failed', description: details[:last_operation][:description])
          DeleteComplete.new
        end
      rescue => e
        update_last_operation(binding, description: e.message)

        DeleteInProgress.new(nil)
      end

      private

      attr_reader :service_event_repository

      def send_unbind_to_broker(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.unbind(binding, nil, true)
        details[:async] ? DeleteStarted.new(details[:operation]) : DeleteComplete.new
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
          broker_provided_operation: operation
        })
      end

      def operation_in_progress!
        raise UnprocessableDelete.new('There is an operation in progress for the service instance')
      end
    end
  end
end
