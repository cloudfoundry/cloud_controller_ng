require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class DeleteRouteBindingJob < VCAP::CloudController::Jobs::CCJob
      def initialize(binding_guid, user_audit_info:)
        super()
        @binding_guid = binding_guid
        @user_audit_info = user_audit_info
      end

      def operation
        :unbind
      end

      def operation_type
        'delete'
      end

      def max_attempts
        1
      end

      def display_name
        'service_route_bindings.delete'
      end

      def resource_guid
        @binding_guid
      end

      def resource_type
        'service_route_binding'
      end

      def perform
        binding = route_binding
        gone! unless binding

        service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(@user_audit_info)
        action = V3::ServiceRouteBindingDelete.new(service_event_repository)
        action.delete(binding, async_allowed: true)
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'unbind', e.message)
      end

      private

      def route_binding
        RouteBinding.first(guid: resource_guid)
      end

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The binding could not be found: #{resource_guid}")
      end
    end
  end
end
