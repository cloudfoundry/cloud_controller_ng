require 'utils/workpool'
require 'cloud_controller/diego/reporters/reporter_mixins'
require 'diego/lrp_constants'

module VCAP::CloudController
  module Diego
    class InstancesReporter
      include ReporterMixins

      UNKNOWN_INSTANCE_COUNT = -1

      def initialize(bbs_instances_client)
        @bbs_instances_client = bbs_instances_client
      end

      def self.singleton_workpool
        @singleton_workpool ||= WorkPool.new(50)
      end

      def all_instances_for_app(process)
        instances = {}
        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances

          current_time_ns = Time.now.to_f * 1e9
          translated_state = LrpStateTranslator.translate_lrp_state(actual_lrp)
          result = {
            state:  translated_state,
            uptime: nanoseconds_to_seconds(current_time_ns - actual_lrp.since),
            since:  nanoseconds_to_seconds(actual_lrp.since),
          }

          result[:details] = actual_lrp.placement_error if actual_lrp.placement_error.present?

          instances[actual_lrp.actual_lrp_key.index] = result
        end

        fill_unreported_instances_with_down_instances(instances, process)
      rescue => e
        raise e if e.is_a? CloudController::Errors::InstancesUnavailable

        logger.error('all_instances_for_app.error', error: e.to_s)
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      def number_of_starting_and_running_instances_for_processes(processes)
        instances = {}
        queue = Queue.new

        workpool = self.class.singleton_workpool
        workpool.replenish

        # Enqueue requests to BBS in the WorkPool to be processed concurrently
        processes.each do |process|
          workpool.submit(process) do |p|
            queue << [p.guid, number_of_starting_and_running_instances_for_process(p)]
          end
        end

        # Collect results of each request, Queue#pop will block while the queue is empty
        processes.each do
          guid, info = queue.pop
          instances[guid] = info
        end

        instances
      end

      def number_of_starting_and_running_instances_for_process(process)
        return 0 unless process.started?

        running_indices = Set.new
        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances
          next unless running_or_starting?(actual_lrp)

          running_indices.add(actual_lrp.actual_lrp_key.index)
        end

        running_indices.length
      rescue => e
        logger.error('number_of_starting_and_running_instances_for_process.error', error: e.to_s)
        UNKNOWN_INSTANCE_COUNT
      end

      def crashed_instances_for_app(process)
        crashed_instances = []
        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          next unless actual_lrp.state == ::Diego::ActualLRPState::CRASHED
          next unless actual_lrp.actual_lrp_key.index < process.instances

          crashed_instances << {
            'instance' => actual_lrp.actual_lrp_instance_key.instance_guid,
            'uptime'   => 0,
            'since'    => nanoseconds_to_seconds(actual_lrp.since),
          }
        end
        crashed_instances
      rescue => e
        raise e if e.is_a? CloudController::Errors::InstancesUnavailable

        logger.error('crashed_instances_for_app.error', error: e.to_s)
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      private

      attr_reader :bbs_instances_client

      def logger
        @logger ||= Steno.logger('cc.diego.instances_reporter')
      end

      def running_or_starting?(lrp)
        translated_state = LrpStateTranslator.translate_lrp_state(lrp)
        return true if VCAP::CloudController::Diego::LRP_RUNNING == translated_state
        return true if VCAP::CloudController::Diego::LRP_STARTING == translated_state

        false
      end
    end

    class LrpStateTranslator
      def self.translate_lrp_state(lrp)
        case lrp.state
        when ::Diego::ActualLRPState::RUNNING
          VCAP::CloudController::Diego::LRP_RUNNING
        when ::Diego::ActualLRPState::CLAIMED
          VCAP::CloudController::Diego::LRP_STARTING
        when ::Diego::ActualLRPState::UNCLAIMED
          lrp.placement_error.present? ? VCAP::CloudController::Diego::LRP_DOWN : VCAP::CloudController::Diego::LRP_STARTING
        when ::Diego::ActualLRPState::CRASHED
          VCAP::CloudController::Diego::LRP_CRASHED
        else
          VCAP::CloudController::Diego::LRP_UNKNOWN
        end
      end
    end
  end
end
