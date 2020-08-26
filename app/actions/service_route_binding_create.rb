module VCAP::CloudController
  module V3
    class ServiceRouteBindingCreate
      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def precursor(service_instance, route)
        not_supported! unless service_instance.route_service?
        not_bindable! unless service_instance.bindable?
        route_is_internal! if route.try(:internal?)
        space_mismatch! unless route.space == service_instance.space
        already_exists! if route.service_instance == service_instance
        already_bound! if route.service_instance

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

      def bind(precursor, parameters: {})
        client = VCAP::Services::ServiceClientProvider.provide(instance: precursor.service_instance)
        details = client.bind(precursor, arbitrary_parameters: parameters)

        precursor.save_with_new_operation(
          {
            route_service_url: details[:binding][:route_service_url]
          },
          {
            type: 'create',
            state: 'succeeded',
          }
        )

        precursor.notify_diego

        service_event_repository.record_service_instance_event(
          :bind_route,
          precursor.service_instance,
          { route_guid: precursor.route.guid },
        )
      end

      class UnprocessableCreate < StandardError; end

      class RouteBindingAlreadyExists < StandardError; end

      private

      attr_reader :service_event_repository

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
