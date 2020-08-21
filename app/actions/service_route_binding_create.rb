module VCAP::CloudController
  module V3
    class ServiceRouteBindingCreate
      def initialize(service_event_repository)
        @service_event_repository = service_event_repository
      end

      def preflight(service_instance, route)
        not_supported! unless service_instance.route_service?
        route_is_internal! if route.try(:internal?)
        space_mismatch! unless route.space == service_instance.space
        already_exists! if route.service_instance == service_instance
        already_bound! if route.service_instance
      end

      def create(service_instance, route)
        binding = RouteBinding.new
        binding.service_instance = service_instance
        binding.route = route

        client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
        details = client.bind(binding)

        binding.route_service_url = details[:binding][:route_service_url]
        binding.save

        binding.notify_diego

        service_event_repository.record_service_instance_event(:bind_route, service_instance, { route_guid: route.guid })

        binding
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

      def already_exists!
        raise RouteBindingAlreadyExists.new('The route and service instance are already bound')
      end
    end
  end
end
