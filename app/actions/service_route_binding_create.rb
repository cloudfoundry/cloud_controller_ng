require 'services/service_brokers/service_client_provider'
require 'actions/v3/service_binding_create'

module VCAP::CloudController
  module V3
    class ServiceRouteBindingCreate < V3::ServiceBindingCreate
      def initialize(service_event_repository)
        super()
        @service_event_repository = service_event_repository
      end

      def precursor(service_instance, route)
        validate!(service_instance, route)

        RouteBinding.new.save_with_new_operation(
          {
            service_instance: service_instance,
            route: route,
          },
          {
            type: 'create',
            state: 'in progress',
          }
        )
      end

      class UnprocessableCreate < StandardError; end

      class RouteBindingAlreadyExists < StandardError; end

      private

      def validate!(service_instance, route)
        not_supported! unless service_instance.route_service?
        not_bindable! unless service_instance.bindable?
        route_is_internal! if route.try(:internal?)
        space_mismatch! unless route.space == service_instance.space
        already_exists! if route.service_instance == service_instance
        already_bound! if route.service_instance
        operation_in_progress! if service_instance.operation_in_progress?
      end

      attr_reader :service_event_repository

      def complete_binding_and_save(binding, binding_details, last_operation)
        binding.save_with_attributes_and_new_operation(
          {
            route_service_url: binding_details[:route_service_url]
          },
          {
            type: 'create',
            state: last_operation[:state],
            description: last_operation[:description],
          }
        )
        binding.notify_diego
        record_audit_event(binding)
      end

      def record_audit_event(precursor)
        service_event_repository.record_service_instance_event(
          :bind_route,
          precursor.service_instance,
          { route_guid: precursor.route.guid },
        )
      end

      def operation_in_progress!
        raise UnprocessableCreate.new('There is an operation in progress for the service instance')
      end

      def route_is_internal!
        raise UnprocessableCreate.new('Route services cannot be bound to internal routes')
      end

      def space_mismatch!
        raise UnprocessableCreate.new('The service instance and the route are in different spaces')
      end

      def already_bound!
        raise UnprocessableCreate.new('A route may only be bound to a single service instance')
      end

      def not_supported!
        raise UnprocessableCreate.new('This service instance does not support route binding')
      end

      def not_bindable!
        raise UnprocessableCreate.new('This service instance does not support binding')
      end

      def already_exists!
        raise RouteBindingAlreadyExists.new('The route and service instance are already bound')
      end
    end
  end
end
