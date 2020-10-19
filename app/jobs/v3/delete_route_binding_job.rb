require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class DeleteRouteBindingJob < Jobs::ReoccurringJob
      def initialize(binding_guid, user_audit_info:)
        super()
        @first_time = true
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
        not_found! unless binding

        service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(@user_audit_info)
        action = V3::ServiceRouteBindingDelete.new(service_event_repository)
        compute_maximum_duration

        if @first_time
          @first_time = false
          delete_result = action.delete(binding, async_allowed: true)
          return finish if delete_result.is_a? V3::ServiceRouteBindingDelete::DeleteComplete
        end

        polling_status = action.poll(binding)
        if polling_status[:finished]
          finish
        end

        if polling_status[:retry_after].present?
          self.polling_interval_seconds = polling_status[:retry_after]
        end
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'unbind', e.message)
      end

      def handle_timeout
        route_binding.save_with_attributes_and_new_operation(
          {},
          {
            type: operation_type,
            state: 'failed',
            description: "Service Broker failed to #{operation} within the required time.",
          }
        )
      end

      private

      def route_binding
        RouteBinding.first(guid: resource_guid)
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = route_binding.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end

      def not_found!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The binding could not be found: #{resource_guid}")
      end
    end
  end
end
