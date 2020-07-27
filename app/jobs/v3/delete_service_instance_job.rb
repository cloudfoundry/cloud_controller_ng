require 'jobs/v3/service_instance_async_job'

module VCAP::CloudController
  module V3
    class DeprovisionBadResponse < StandardError
    end

    class DeleteServiceInstanceJob < ServiceInstanceAsyncJob
      def initialize(guid, audit_info)
        super
      end

      def send_broker_request(client)
        deprovision_response = client.deprovision(service_instance, { accepts_incomplete: true })

        @request_failed = false

        deprovision_response
      rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse => err
        @request_failed = true
        raise DeprovisionBadResponse.new(err.message)
      rescue CloudController::Errors::ApiError => err
        raise OperationAborted.new('The service broker rejected the request') if err.name == 'AsyncServiceInstanceOperationInProgress'

        raise err
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

      def pollable_job_state
        return PollableJobModel::PROCESSING_STATE if @request_failed

        PollableJobModel::POLLING_STATE
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
