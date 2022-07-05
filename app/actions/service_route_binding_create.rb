require 'services/service_brokers/service_client_provider'
require 'actions/metadata_update'
require 'actions/v3/service_binding_create'

module VCAP::CloudController
  module V3
    class ServiceRouteBindingCreate < V3::ServiceBindingCreate
      def initialize(user_audit_info, audit_hash)
        super()
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
        @manifest_triggered = false
      end

      PERMITTED_BINDING_ATTRIBUTES = [:route_service_url].freeze

      def precursor(service_instance, route, message:)
        validate!(service_instance, route)

        binding_details = {
          service_instance: service_instance,
          route: route,
        }

        RouteBinding.new.tap do |b|
          RouteBinding.db.transaction do
            b.save_with_attributes_and_new_operation(
              binding_details,
              CREATE_INITIAL_OPERATION
            )
            MetadataUpdate.update(b, message)
          end
        end
      end

      class RouteBindingAlreadyExists < StandardError; end

      private

      def event_repository
        @event_repository ||= Repositories::ServiceGenericBindingEventRepository.new(
          Repositories::ServiceGenericBindingEventRepository::SERVICE_ROUTE_BINDING)
      end

      def validate!(service_instance, route)
        not_supported! unless service_instance.route_service?
        not_bindable! unless service_instance.bindable?
        route_is_internal! if route.try(:internal?)
        space_mismatch! unless route.space == service_instance.space
        already_exists! if route.service_instance == service_instance
        already_bound! if route.service_instance
        if service_instance.managed_instance?
          service_instance_not_found! if service_instance.create_failed?
          operation_in_progress! if service_instance.operation_in_progress?
        end
      end

      def permitted_binding_attributes
        PERMITTED_BINDING_ATTRIBUTES
      end

      def post_bind_action(binding)
        binding.notify_diego
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
