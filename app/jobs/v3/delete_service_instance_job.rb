require 'jobs/v3/service_instance_async_job'

module VCAP::CloudController
  module V3
    class DeprovisionBadResponse < StandardError
    end

    class DeleteServiceInstanceJob < ServiceInstanceAsyncJob
      def initialize(guid, audit_info)
        super(guid, audit_info)
      end

      def send_broker_request(client)
        client.deprovision(service_instance, { accepts_incomplete: true })
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse => err
        raise DeprovisionBadResponse.new(err.message)
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

      def gone!
        finish
      end

      def restart_on_failure?
        true
      end

      def restart_job(msg)
        super
        logger.info("could not complete the operation: #{msg}. Triggering orphan mitigation")
      end

      def fail!(err)
        case err
        when DeprovisionBadResponse
          trigger_orphan_mitigation(err)
        else
          super
        end
      end

      private

      def trigger_orphan_mitigation(err)
        restart_job(err.message)
      end
    end
  end
end
