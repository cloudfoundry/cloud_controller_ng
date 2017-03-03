require 'diego/client'
require 'diego/actual_lrp_group_resolver'

module VCAP::CloudController
  module Diego
    class BbsInstancesClient
      def initialize(client)
        @client = client
      end

      def lrp_instances(process)
        process_guid = ProcessGuid.from_process(process)
        logger.info('lrp.instances.request', process_guid: process_guid)

        actual_lrp_groups = handle_diego_errors do
          response = @client.actual_lrp_groups_by_process_guid(process_guid)
          logger.info('lrp.instances.response', process_guid: process_guid, error: response.error)
          response
        end

        actual_lrp_groups.actual_lrp_groups.map do |actual_lrp_group|
          ::Diego::ActualLRPGroupResolver.get_lrp(actual_lrp_group)
        end
      end

      def desired_lrp_instance(process)
        process_guid = ProcessGuid.from_process(process)
        response = handle_diego_errors do
          @client.desired_lrp_by_process_guid(process_guid)
        end
        response.desired_lrp
      end

      private

      def handle_diego_errors
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::InstancesUnavailable.new(e)
        end

        if response.error
          if response.error.type == ::Diego::Bbs::Models::Error::Type::ResourceNotFound
            raise CloudController::Errors::NoRunningInstances.new('No running instances found for given process guid')
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
