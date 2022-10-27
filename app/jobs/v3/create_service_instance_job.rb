require 'jobs/reoccurring_job'
require 'actions/v3/service_instance_create_managed'

module VCAP::CloudController
  module V3
    class CreateServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :warnings

      def initialize(
        service_instance_guid,
        arbitrary_parameters: {},
        user_audit_info:,
        audit_hash:
      )
        super()
        @service_instance_guid = service_instance_guid
        @arbitrary_parameters = arbitrary_parameters
        @user_audit_info = user_audit_info
        @audit_hash = audit_hash
        @warnings = []
        @first_time = true
      end

      def action
        V3::ServiceInstanceCreateManaged.new(@user_audit_info, @audit_hash)
      end

      def operation
        :provision
      end

      def operation_type
        'create'
      end

      def max_attempts
        1
      end

      def display_name
        'service_instance.create'
      end

      def resource_type
        'service_instances'
      end

      def resource_guid
        @service_instance_guid
      end

      def perform
        not_found! unless service_instance

        raise_if_other_operations_in_progress!

        compute_maximum_duration

        begin
          if @first_time
            @first_time = false
            action.provision(service_instance, parameters: @arbitrary_parameters, accepts_incomplete: true)
            compatibility_checks
            return finish if service_instance.reload.terminal_state?
          end

          polling_status = action.poll(service_instance)

          if polling_status[:finished]
            finish
          end

          if polling_status[:retry_after].present?
            self.polling_interval_seconds = polling_status[:retry_after]
          end
        rescue ServiceInstanceCreateManaged::LastOperationFailedState => e
          raise e
        rescue CloudController::Errors::ApiError => e
          save_failure(e)
          raise e
        rescue => e
          save_failure(e)
          raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'provision', e.message)
        end
      end

      def handle_timeout
        service_instance.save_with_new_operation(
          {},
          {
            type: 'create',
            state: 'failed',
            description: "Service Broker failed to #{operation} within the required time.",
          }
        )
      end

      def compatibility_checks
        if service_instance.service_plan.service.volume_service? && volume_services_disabled?
          @warnings.push({ detail: ServiceInstance::VOLUME_SERVICE_WARNING })
        end

        if service_instance.service_plan.service.route_service? && route_services_disabled?
          @warnings.push({ detail: ServiceInstance::ROUTE_SERVICE_WARNING })
        end
      end

      def volume_services_disabled?
        !VCAP::CloudController::Config.config.get(:volume_services_enabled)
      end

      def route_services_disabled?
        !VCAP::CloudController::Config.config.get(:route_services_enabled)
      end

      private

      attr_reader :user_audit_info

      def service_instance
        ManagedServiceInstance.first(guid: @service_instance_guid)
      end

      def raise_if_other_operations_in_progress!
        last_operation_type = service_instance.last_operation&.type

        if service_instance.operation_in_progress? && last_operation_type != operation_type
          cancelled!(last_operation_type)
        end
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan
      end

      def save_failure(error_message)
        if service_instance.reload.last_operation.state != 'failed'
          service_instance.save_with_new_operation(
            {},
            {
              type: 'create',
              state: 'failed',
              description: error_message,
            }
          )
        end
      end

      def not_found!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The service instance could not be found: #{@service_instance_guid}.")
      end

      def cancelled!(operation_in_progress)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, "#{operation_in_progress} in progress")
      end
    end
  end
end
