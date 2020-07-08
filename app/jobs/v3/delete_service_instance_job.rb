require 'jobs/reoccurring_job'

module VCAP::CloudController
  module V3
    class DeleteServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :warnings

      def initialize(guid, operation, audit_info)
        super()
        @service_instance_guid = guid
        @operation = operation
        @client_arguments = { accepts_incomplete: false }
        @user_audit_info = audit_info
        @warnings = []
      end

      def perform
        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

        execute_request(client)

        finish
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

      def service_instance
        ManagedServiceInstance.first(guid: @service_instance_guid)
      end

      def execute_request(client)
        broker_response = client.public_send(
          @operation,
          service_instance,
          @client_arguments
        )

        if broker_response.dig(:last_operation, :state) == 'succeeded'
          ServiceInstance.db.transaction do
            si = service_instance
            service_instance.lock!
            service_instance.last_operation&.destroy
            service_instance.destroy
            record_event(si, nil)
          end
        end
      rescue => e
        service_instance.save_with_new_operation({}, {
          type: operation_type,
          state: 'failed',
          description: e.message,
        })
        raise e
      end

      def record_event(service_instance, request_attrs)
        Repositories::ServiceEventRepository.new(@user_audit_info).
          record_service_instance_event(:delete, service_instance, request_attrs)
      end

      def operation_type
        case @operation
        when :deprovision
          'delete'
        else
          ''
        end
      end
    end
  end
end
