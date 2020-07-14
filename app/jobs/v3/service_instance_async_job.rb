require 'jobs/reoccurring_job'

module VCAP::CloudController
  module V3
    class ServiceInstanceAsyncJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :warnings

      def initialize(guid, audit_info)
        super()
        @service_instance_guid = guid
        @user_audit_info = audit_info
        @warnings = []
        @request_attr = {}
        @first_time = true
      end

      def perform
        gone! && return if service_instance.blank?
        last_operation_type = service_instance.last_operation&.type

        if service_instance.operation_in_progress? && last_operation_type != operation_type
          aborted!(last_operation_type)
        end

        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

        begin
          if @first_time
            compute_maximum_duration
            execute_request(client)
            compatibility_checks
            @first_time = false
          end

          if service_instance.operation_in_progress?
            fetch_last_operation(client)
          end

          if operation_completed?
            si = service_instance
            operation_succeeded
            record_event(si, @request_attr)
            finish
          end
        rescue => err
          fail!(err)
        end

        if service_instance.present? && service_instance.last_operation.state == 'failed'
          operation_failed!(service_instance.last_operation.description)
        end
      end

      def handle_timeout
        service_instance.save_and_update_operation(
          last_operation: {
            state: 'failed',
            description: "Service Broker failed to #{operation} within the required time.",
          }
        )
      end

      def job_name_in_configuration
        "service_instance_#{operation_type}"
      end

      def max_attempts
        1
      end

      def resource_type
        'service_instances'
      end

      def resource_guid
        service_instance_guid
      end

      def display_name
        "service_instance.#{operation_type}"
      end

      private

      attr_reader :service_instance_guid

      def execute_request(client)
        broker_response = send_broker_request(client)

        service_instance.save_with_new_operation(
          broker_response[:instance] || {},
          broker_response[:last_operation] || {}
        )
      end

      def operation_completed?
        service_instance.last_operation.state == 'succeeded' && service_instance.last_operation.type == operation_type
      end

      def fetch_last_operation(client)
        last_operation_result = client.fetch_service_instance_last_operation(service_instance)
        self.polling_interval_seconds = last_operation_result[:retry_after] if last_operation_result[:retry_after]

        service_instance.save_and_update_operation(
          last_operation: last_operation_result[:last_operation].slice(:state, :description)
        )
      rescue HttpRequestError, HttpResponseError, Sequel::Error => e
        logger = Steno.logger('cc-background')
        logger.error("There was an error while fetching the service instance operation state: #{e}")
      end

      def compute_maximum_duration
        max_poll_duration_on_plan = service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan if max_poll_duration_on_plan
      end

      def service_instance
        ManagedServiceInstance.first(guid: @service_instance_guid)
      end

      def record_event(service_instance, request_attrs)
        Repositories::ServiceEventRepository.new(@user_audit_info).
          record_service_instance_event(operation_type, service_instance, request_attrs)
      end

      def aborted!(operation_in_progress)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, "#{operation_in_progress} in progress")
      end

      def operation_failed!(msg)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, msg)
      end

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The service instance could not be found: #{service_instance_guid}")
      end

      def operation_succeeded
        nil
      end

      def fail!(e)
        unless service_instance.blank?
          service_instance.save_with_new_operation({}, {
            type: operation_type,
            state: 'failed',
            description: e.message,
          })
        end

        raise e
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
    end
  end
end
