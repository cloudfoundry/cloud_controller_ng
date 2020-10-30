require 'jobs/reoccurring_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class DeleteCredentialBindingJob < Jobs::ReoccurringJob
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
        'service_credential_bindings.delete'
      end

      def resource_guid
        @binding_guid
      end

      def resource_type
        'service_credential_binding'
      end

      def perform
        V3::ServiceCredentialBindingDelete.new.delete(service_credential_binding)
        return finish

        # return finish
        # binding = credential_binding
        # return finish if binding.nil?
        #
        # service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(@user_audit_info)
        # action = V3::ServiceRouteBindingDelete.new(service_event_repository)
        # compute_maximum_duration
        #
        # if @first_time
        #   @first_time = false
        #   delete_result = action.delete(binding, async_allowed: true)
        #   if delete_result[:finished]
        #     return finish
        #   end
        # end
        #
        # polling_status = action.poll(binding)
        # if polling_status[:finished]
        #   return finish
        # end
        #
        # if polling_status[:retry_after].present?
        #   self.polling_interval_seconds = polling_status[:retry_after]
        # end
      rescue => e
        if credential_binding.reload.last_operation.state != 'failed' && !e.is_a?(V3::ServiceRouteBindingDelete::ConcurrencyError)
          save_failure(e.message)
        end
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'unbind', e.message)
      end

      def handle_timeout
        save_failure("Service Broker failed to #{operation} within the required time.")
      end

      private

      def save_failure(description)
        credential_binding.save_with_attributes_and_new_operation(
          {},
          {
            type: operation_type,
            state: 'failed',
            description: description,
          }
        )
      end

      def credential_binding
        ServiceBinding.first(guid: resource_guid)
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = credential_binding.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end
    end
  end
end
