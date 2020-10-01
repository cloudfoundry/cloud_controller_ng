require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class CreateRouteBindingJobActor
      def display_name
        'service_route_bindings.create'
      end

      def resource_type
        'service_route_binding'
      end

      def get_resource(resource_id)
        RouteBinding.first(guid: resource_id)
      end

      def new_action(user_audit_info, audit_hash)
        service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
        V3::ServiceRouteBindingCreate.new(service_event_repository)
      end
    end

    class CreateRouteBindingJob < Jobs::ReoccurringJob
      def initialize(precursor_guid, parameters:, user_audit_info:)
        super()
        @precursor_guid = precursor_guid
        @user_audit_info = user_audit_info
        @parameters = parameters
        @first_time = true
      end

      def operation
        :bind
      end

      def operation_type
        'create'
      end

      def max_attempts
        1
      end

      def display_name
        'service_route_bindings.create'
      end

      def resource_guid
        @precursor_guid
      end

      def resource_type
        'service_route_binding'
      end

      def perform
        precursor = route_binding
        gone! unless precursor

        service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(@user_audit_info)
        action = V3::ServiceRouteBindingCreate.new(service_event_repository)
        compute_maximum_duration

        if @first_time
          @first_time = false
          action.bind(precursor, parameters: @parameters, accepts_incomplete: true)
          return finish if precursor.reload.terminal_state?
        end

        polling_status = action.poll(precursor)
        case polling_status
        when ServiceRouteBindingCreate::PollingComplete
          finish
        when ServiceRouteBindingCreate::PollingNotComplete
          unless polling_status.retry_after.nil?
            self.polling_interval_seconds = polling_status.retry_after.to_i
          end
        end
      rescue ServiceRouteBindingCreate::BindingNotRetrievable
        raise CloudController::Errors::ApiError.new_from_details('ServiceBindingInvalid', 'The broker responded asynchronously but does not support fetching binding data')
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'bind', e.message)
      end

      def handle_timeout
        route_binding.save_with_new_operation(
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
        RouteBinding.first(guid: @precursor_guid)
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = route_binding.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The binding could not be found: #{@precursor_guid}")
      end
    end
  end
end
