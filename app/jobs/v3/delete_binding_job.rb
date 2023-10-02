require 'jobs/reoccurring_job'
require 'cloud_controller/errors/api_error'
require 'actions/service_route_binding_delete'
require 'jobs/v3/delete_service_binding_job_factory'

module VCAP::CloudController
  module V3
    class DeleteBindingJob < Jobs::ReoccurringJob
      def initialize(type, binding_guid, user_audit_info:)
        super()
        @type = type
        @binding_guid = binding_guid
        @user_audit_info = user_audit_info
      end

      def actor
        DeleteServiceBindingFactory.for(@type)
      end

      def action
        DeleteServiceBindingFactory.action(@type, @user_audit_info)
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

      delegate :display_name, to: :actor

      def resource_guid
        @binding_guid
      end

      delegate :resource_type, to: :actor

      def perform
        return finish if binding.nil?

        compute_maximum_duration

        unless delete_in_progress?
          delete_result = action.delete(binding)
          return finish if delete_result[:finished]
        end

        polling_status = action.poll(binding)
        return finish if polling_status[:finished]

        self.polling_interval_seconds = polling_status[:retry_after] if polling_status[:retry_after].present?
      rescue StandardError => e
        save_failure(e.message) if binding.reload.last_operation.state != 'failed' && !e.is_a?(V3::ServiceRouteBindingDelete::ConcurrencyError)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'unbind', e.message)
      end

      def handle_timeout
        save_failure("Service Broker failed to #{operation} within the required time.")
      end

      private

      def binding
        actor.get_resource(resource_guid)
      end

      def delete_in_progress?
        binding.last_operation&.type == 'delete' &&
          binding.last_operation&.state == 'in progress'
      end

      def save_failure(description)
        binding.save_with_attributes_and_new_operation(
          {},
          {
            type: operation_type,
            state: 'failed',
            description: description
          }
        )
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = binding.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end
    end
  end
end
