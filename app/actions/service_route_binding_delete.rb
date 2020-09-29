module VCAP::CloudController
  module V3
    class ServiceRouteBindingDelete
      class UnprocessableDelete < StandardError; end

      RequiresAsync = Class.new.freeze
      DeleteComplete = Class.new.freeze
      DeleteInProgress = Struct.new(:operation).freeze

      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def delete(binding, async_allowed:)
        return RequiresAsync unless async_allowed || binding.service_instance.user_provided_instance?

        operation_in_progress! if binding.service_instance.operation_in_progress?

        result = send_unbind_to_broker(binding)
        unsupported! unless result == DeleteComplete

        record_audit_event(binding)
        binding.destroy
        binding.notify_diego

        DeleteComplete
      rescue => e
        binding.save_with_new_operation({}, {
          type: 'delete',
          state: 'failed',
          description: e.message,
        })

        raise e
      end

      private

      attr_reader :service_event_repository

      def send_unbind_to_broker(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.unbind(binding, accepts_incomplete: false)
        details[:async] ? DeleteInProgress.new(details[:operation]) : DeleteComplete
      rescue => err
        raise UnprocessableDelete.new("Service broker failed to delete service binding for instance #{binding.service_instance.name}: #{err.message}")
      end

      def record_audit_event(binding)
        service_event_repository.record_service_instance_event(
          :unbind_route,
          binding.service_instance,
          { route_guid: binding.route.guid },
        )
      end

      def operation_in_progress!
        raise UnprocessableDelete.new('There is an operation in progress for the service instance')
      end

      def unsupported!
        raise UnprocessableDelete.new('async unbind not supported yet')
      end
    end
  end
end
