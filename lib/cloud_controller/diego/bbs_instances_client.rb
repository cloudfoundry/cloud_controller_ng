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

        bbs_lrp_groups = handle_diego_errors do
          response = @client.actual_lrp_groups_by_process_guid(process_guid)
          logger.info('lrp.instances.response', process_guid: process_guid, error: response.error)
          response
        end

        instances = bbs_lrp_groups.actual_lrp_groups.map do |actual_lrp_group|
          actual_lrp = resolve(actual_lrp_group)
          {
            process_guid: actual_lrp.actual_lrp_key.process_guid,
            instance_guid: actual_lrp.actual_lrp_instance_key.instance_guid,
            index: actual_lrp.actual_lrp_key.index,
            since: actual_lrp.since,
            uptime: Time.now.to_i - actual_lrp.since,
            state: actual_lrp.state,
            net_info: actual_lrp.actual_lrp_net_info,
          }
        end

        instances
      end

      def resolve(actual_lrp_group)
        return actual_lrp_group.instance if actual_lrp_group.instance
        return actual_lrp_group.evacuating if actual_lrp_group.evacuating
        raise CloudController::Errors::InstancesUnavailable.new('no instance or evacuating object in actual_lrp_group')
      end

      private

      def handle_diego_errors
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::InstancesUnavailable.new(e)
        end

        if response.error
          raise CloudController::Errors::InstancesUnavailable.new(response.error.message)
        end

        response
      end

      def logger
        @logger ||= Steno.logger('cc.bbs.instances_client')
      end
    end
  end
end
