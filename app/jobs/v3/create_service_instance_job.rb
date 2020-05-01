require 'jobs/reoccurring_job'

module VCAP::CloudController
  module V3
    class CreateServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :warnings

      def initialize(service_instance_guid, arbitrary_parameters: {}, user_audit_info:)
        super()
        @service_instance_guid = service_instance_guid
        @arbitrary_parameters = arbitrary_parameters
        @user_audit_info = user_audit_info
        @start_time = Time.now
        @first_time = true
        @warnings = []
      end

      def perform
        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

        if first_time
          compute_maximum_duration
          send_provision_request(client)
          compatibility_checks
          @first_time = false
        end

        gone! if service_instance.nil?

        operation_in_progress = service_instance.last_operation.type
        aborted! if operation_in_progress != 'create'

        if service_instance.operation_in_progress?
          fetch_last_operation(client)
        end

        if service_instance.last_operation.state == 'succeeded'
          record_event(service_instance, @arbitrary_parameters)
          finish
        elsif service_instance.last_operation.state == 'failed'
          operation_failed!(service_instance.last_operation.description)
        end
      end

      def handle_timeout
        service_instance.save_and_update_operation(
          last_operation: {
            state: 'failed',
            description: 'Service Broker failed to provision within the required time.',
          }
        )
      end

      def job_name_in_configuration
        :service_instance_create
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
        'service_instance.create'
      end

      private

      attr_reader :service_instance_guid, :arbitrary_parameters, :first_time

      def compute_maximum_duration
        max_poll_duration_on_plan = service_instance.service_plan.try(:maximum_polling_duration)
        self.maximum_duration_seconds = max_poll_duration_on_plan if max_poll_duration_on_plan
      end

      def send_provision_request(client)
        broker_response = client.provision(
          service_instance,
          accepts_incomplete: true,
          arbitrary_parameters: arbitrary_parameters,
          maintenance_info: service_instance.service_plan.maintenance_info
        )

        service_instance.save_with_new_operation(broker_response[:instance], broker_response[:last_operation])
      rescue => e
        service_instance.save_with_new_operation({}, {
          type: 'create',
          state: 'failed',
          description: e.message,
        })
        raise e
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

      def record_event(service_instance, request_attrs)
        Repositories::ServiceEventRepository.new(@user_audit_info).
          record_service_instance_event(:create, service_instance, request_attrs)
      end

      def service_instance
        ManagedServiceInstance.first(guid: service_instance_guid)
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

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', service_instance_guid)
      end

      def aborted!
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'Create', 'delete in progress')
      end

      def operation_failed!(msg)
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceProvisionFailed', msg)
      end
    end
  end
end
