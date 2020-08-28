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

      def bind(precursor, parameters: {}, accepts_incomplete: false)
        client = VCAP::Services::ServiceClientProvider.provide(instance: precursor.service_instance)
        details = client.bind(precursor, arbitrary_parameters: parameters, accepts_incomplete: accepts_incomplete)

        if details[:async]
          not_retrievable! unless bindings_retrievable?(precursor)
          save_incomplete_binding(precursor, details[:operation])
        else
          complete_binding_and_save(precursor, details[:binding][:route_service_url])
        end
      rescue => e
        precursor.save_with_new_operation({}, {
          type: 'create',
          state: 'failed',
          description: e.message,
        })

        raise e
      end

      def poll(binding)
        client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)
        details = client.fetch_service_binding_last_operation(binding)
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
          PollingComplete.new
        else
          PollingNotComplete.new(details[:retry_after])
        end
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse,
             VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed => e

        binding.save_with_new_operation({}, {
          type: 'create',
          state: 'failed',
          description: e.message,
        })

        raise e
      rescue => e
        binding.save_with_new_operation({}, {
          type: 'create',
          state: 'failed',
          description: e.message,
        })

        return PollingComplete.new
      end

      PollingComplete = Class.new.freeze
      PollingNotComplete = Struct.new(:retry_after).freeze

      class UnprocessableCreate < StandardError; end

      class RouteBindingAlreadyExists < StandardError; end

      class BindingNotRetrievable < StandardError; end

      private

      attr_reader :service_event_repository

      def save_incomplete_binding(precursor, operation)
        precursor.save_with_new_operation({},
          {
            type: 'create',
            state: 'in progress',
            broker_provided_operation: operation
          }
        )
      end

      def complete_binding_and_save(precursor, route_service_url)
        save_with_route_service_url(precursor, route_service_url)
        precursor.notify_diego
        record_audit_event(precursor)
      end

      def save_with_route_service_url(precursor, route_service_url)
        precursor.save_with_new_operation(
          {
            route_service_url: route_service_url
          },
          {
            type: 'create',
            state: 'succeeded',
          }
        )
      end

      def record_audit_event(precursor)
        service_event_repository.record_service_instance_event(
          :bind_route,
          precursor.service_instance,
          { route_guid: precursor.route.guid },
        )
      end

      def bindings_retrievable?(binding)
        binding.service_instance.service.bindings_retrievable
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

      def not_retrievable!
        raise BindingNotRetrievable.new('The broker responded asynchronously but does not support fetching binding data')
      end
    end
  end
end
