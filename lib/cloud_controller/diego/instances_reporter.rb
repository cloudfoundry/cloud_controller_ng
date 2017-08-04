require 'cloud_controller/diego/process_stats_generator'
require 'traffic_controller/client'
require 'utils/workpool'

module VCAP::CloudController
  module Diego
    class InstancesReporter
      UNKNOWN_INSTANCE_COUNT = -1

      def initialize(bbs_instances_client, traffic_controller_client)
        @bbs_instances_client      = bbs_instances_client
        @traffic_controller_client = traffic_controller_client
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
        workpool = WorkPool.new(50)
        queue = Queue.new

        processes.each do |process|
          workpool.submit(instances, process) do |i, p|
            queue << [p.guid, number_of_starting_and_running_instances_for_process(p)]
          end
        end

        workpool.drain
        until queue.empty?
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
        return UNKNOWN_INSTANCE_COUNT
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

      def stats_for_app(process)
        result       = {}
        current_time = Time.now.to_f
        formatted_current_time = Time.now.to_datetime.rfc3339

        logger.debug('stats_for_app.fetching_container_metrics', process_guid: process.guid)
        envelopes = @traffic_controller_client.container_metrics(
          app_guid: process.guid,
          auth_token: VCAP::CloudController::SecurityContext.auth_token,
        )
        actual_lrps = bbs_instances_client.lrp_instances(process)
        desired_lrp = bbs_instances_client.desired_lrp_instance(process)

        stats = {}
        envelopes.each do |envelope|
          container_metrics                      = envelope.containerMetric
          stats[container_metrics.instanceIndex] = {
            time: formatted_current_time,
            cpu:  container_metrics.cpuPercentage / 100,
            mem:  container_metrics.memoryBytes,
            disk: container_metrics.diskBytes,
          }
        end

        actual_lrps.each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances
          info = {
            state: LrpStateTranslator.translate_lrp_state(actual_lrp),
            isolation_segment: desired_lrp.PlacementTags.first,
            stats: {
              name:       process.name,
              uris:       process.uris,
              host:       actual_lrp.actual_lrp_net_info.address,
              port:       get_default_port(actual_lrp.actual_lrp_net_info),
              net_info:   actual_lrp.actual_lrp_net_info.to_hash,
              uptime:     nanoseconds_to_seconds(current_time * 1e9 - actual_lrp.since),
              mem_quota:  process[:memory] * 1024 * 1024,
              disk_quota: process[:disk_quota] * 1024 * 1024,
              fds_quota:  process.file_descriptors,
              usage:      stats[actual_lrp.actual_lrp_key.index] || {
                time: formatted_current_time,
                cpu:  0,
                mem:  0,
                disk: 0,
              },
            }
          }
          info[:details]                          = actual_lrp.placement_error if actual_lrp.placement_error.present?
          result[actual_lrp.actual_lrp_key.index] = info
        end

        fill_unreported_instances_with_down_instances(result, process)
      rescue CloudController::Errors::NoRunningInstances => e
        logger.info('stats_for_app.error', error: e.to_s)
        fill_unreported_instances_with_down_instances({}, process)
      rescue => e
        logger.error('stats_for_app.error', error: e.to_s)
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

      def nanoseconds_to_seconds(time)
        (time / 1e9).to_i
      end

      def fill_unreported_instances_with_down_instances(reported_instances, process)
        process.instances.times do |i|
          unless reported_instances[i]
            reported_instances[i] = {
              state:  'DOWN',
              uptime: 0,
            }
          end
        end

        reported_instances
      end

      def get_default_port(net_info)
        net_info.ports.each do |port_mapping|
          return port_mapping.host_port if port_mapping.container_port == DEFAULT_APP_PORT
        end

        0
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
