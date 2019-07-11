require 'diego/client'

module VCAP::CloudController
  module Diego
    class BbsInstancesClient
      def initialize(client)
        @client = client
      end

      def lrp_instances(process)
        process_guid = ProcessGuid.from_process(process)
        logger.info('lrp.instances.request', process_guid: process_guid)

        actual_lrps_response = handle_diego_errors(process_guid) do
          response = @client.actual_lrps_by_process_guid(process_guid)
          logger.info('lrp.instances.response', process_guid: process_guid, error: response.error)
          response
        end

        actual_lrps_response.actual_lrps
      end

      def desired_lrp_instance(process)
        process_guid = ProcessGuid.from_process(process)
        response = handle_diego_errors(process_guid) do
          @client.desired_lrp_by_process_guid(process_guid)
        end
        response.desired_lrp
      end

      private

      def handle_diego_errors(process_guid)
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::InstancesUnavailable.new(e)
        end

        if response.error
          if response.error.type == ::Diego::Bbs::ErrorTypes::ResourceNotFound
            raise CloudController::Errors::NoRunningInstances.new("No running instances found for process guid #{process_guid}")
          else
            raise CloudController::Errors::InstancesUnavailable.new(response.error.message)
          end

        end

        response
      end

      def logger
        @logger ||= Steno.logger('cc.bbs.instances_client')
      end
    end
  end
end
