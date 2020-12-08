require 'jobs/reoccurring_job'
require 'actions/service_route_binding_create'
require 'actions/service_credential_binding_app_create'
require 'cloud_controller/errors/api_error'
require 'jobs/v3/create_service_binding_job_factory'

module VCAP::CloudController
  module V3
    class CreateBindingAsyncJob < Jobs::ReoccurringJob
      class OperationCancelled < StandardError; end

      class BindingNotFound < CloudController::Errors::ApiError; end

      def initialize(type, precursor_guid, parameters:, user_audit_info:, audit_hash:)
        super()
        @type = type
        @resource_guid = precursor_guid
        @parameters = parameters
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
        @first_time = true
      end

      def actor
        CreateServiceBindingFactory.for(@type)
      end

      def action
        CreateServiceBindingFactory.action(@type, @user_audit_info, @audit_hash)
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
        actor.display_name
      end

      def resource_guid
        @resource_guid
      end

      def resource_type
        actor.resource_type
      end

      def perform
        not_found! unless resource

        cancelled! if delete_in_progress?

        compute_maximum_duration

        if @first_time
          @first_time = false
          action.bind(resource, parameters: @parameters, accepts_incomplete: true)

          return finish if resource.reload.terminal_state?
        end

        polling_status = action.poll(resource)

        if polling_status[:finished]
          finish
        end

        if polling_status[:retry_after].present?
          self.polling_interval_seconds = polling_status[:retry_after]
        end
      rescue OperationCancelled => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, e.message)
      rescue BindingNotFound => e
        raise e
      rescue ServiceBindingCreate::BindingNotRetrievable
        raise CloudController::Errors::ApiError.new_from_details('ServiceBindingInvalid', 'The broker responded asynchronously but does not support fetching binding data')
      rescue => e
        save_failure(e.message)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'bind', e.message)
      end

      def handle_timeout
        resource.save_with_attributes_and_new_operation(
          {},
          {
            type: operation_type,
            state: 'failed',
            description: "Service Broker failed to #{operation} within the required time.",
          }
        )
      end

      private

      def resource
        actor.get_resource(resource_guid)
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = resource.service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end

      def not_found!
        raise BindingNotFound.new_from_details('ResourceNotFound', "The binding could not be found: #{@resource_guid}")
      end

      def delete_in_progress?
        resource.operation_in_progress? && resource.last_operation&.type == 'delete'
      end

      def cancelled!
        raise OperationCancelled.new("#{resource.last_operation.type} in progress")
      end

      def save_failure(error_message)
        if resource.reload.last_operation.state != 'failed'
          resource.save_with_attributes_and_new_operation(
            {},
            {
              type: operation_type,
              state: 'failed',
              description: error_message,
            }
          )
        end
      end
    end
  end
end
