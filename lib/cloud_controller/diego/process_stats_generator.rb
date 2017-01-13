module VCAP::CloudController
  module Diego
    class ProcessStatsGenerator
      def generate(process)
        bbs_instances_client.lrp_instances(process).map do |actual_lrp|
          {
            instance_guid: actual_lrp.actual_lrp_instance_key.instance_guid,
            index: actual_lrp.actual_lrp_key.index,
            since: actual_lrp.since,
            uptime: Time.now.to_i - actual_lrp.since,
            state: actual_lrp.state,
          }.tap do |h|
            h[:details] = actual_lrp.placement_error if actual_lrp.placement_error.present?
          end
        end
      end

      def bulk_generate(processes)
        processes.map do |process|
          generate(process)
        end
      end

      private

      def bbs_instances_client
        CloudController::DependencyLocator.instance.bbs_instances_client
      end

      def resolve(actual_lrp_group)
        return actual_lrp_group.instance if actual_lrp_group.instance
        return actual_lrp_group.evacuating if actual_lrp_group.evacuating
        raise CloudController::Errors::InstancesUnavailable.new('no instance or evacuating object in actual_lrp_group')
      end
    end
  end
end
