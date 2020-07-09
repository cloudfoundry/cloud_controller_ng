require 'jobs/v3/service_instance_async_job'

module VCAP::CloudController
  module V3
    class DeleteServiceInstanceJob < ServiceInstanceAsyncJob
      def initialize(guid, audit_info)
        super(guid, audit_info)
      end

      def send_broker_request(client)
        client.deprovision(service_instance, { accepts_incomplete: true })
      end

      def operation_succeeded
        ServiceInstance.db.transaction do
          service_instance.lock!
          service_instance.last_operation&.destroy
          service_instance.destroy
        end
      end

      def operation
        :deprovision
      end

      def operation_type
        'delete'
      end

      private

      def gone!
        finish
      end

      def compatibility_checks
        nil
      end
    end
  end
end
