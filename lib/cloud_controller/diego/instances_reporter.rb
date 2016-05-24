module VCAP::CloudController
  module Diego
    class InstancesReporter
      attr_reader :tps_client

      def initialize(tps_client)
        @tps_client = tps_client
      end

      def all_instances_for_app(process)
        result    = {}
        instances = tps_client.lrp_instances(process)

        for_each_desired_instance(instances, process) do |instance|
          info = {
            state: instance[:state],
            uptime: instance[:uptime],
            since: instance[:since],
          }
          info[:details] = instance[:details] if instance[:details]
          result[instance[:index]] = info
        end

        fill_unreported_instances_with_down_instances(result, process)
      rescue CloudController::Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      def number_of_starting_and_running_instances_for_processes(processes)
        result = {}

        instances_map = tps_client.bulk_lrp_instances(processes)
        processes.each do |application|
          running_indices = Set.new

          for_each_desired_instance(instances_map[application.guid] || [], application) do |instance|
            next unless instance[:state] == 'RUNNING' || instance[:state] == 'STARTING'
            running_indices.add(instance[:index])
          end

          result[application.guid] = running_indices.length
        end

        result
      rescue CloudController::Errors::InstancesUnavailable
        processes.each { |process| result[process.guid] = -1 }
        result
      rescue => e
        logger.error('tps.error', error: e.to_s)
        processes.each { |process| result[process.guid] = -1 }
        result
      end

      def number_of_starting_and_running_instances_for_process(process)
        return 0 unless process.started?
        instances = tps_client.lrp_instances(process)

        running_indices = Set.new

        for_each_desired_instance(instances, process) do |instance|
          next unless instance[:state] == 'RUNNING' || instance[:state] == 'STARTING'
          running_indices.add(instance[:index])
        end

        running_indices.length
      rescue CloudController::Errors::InstancesUnavailable
        return -1
      rescue => e
        logger.error('tps.error', error: e.to_s)
        return -1
      end

      def crashed_instances_for_app(process)
        result    = []
        instances = tps_client.lrp_instances(process)

        for_each_desired_instance(instances, process) do |instance|
          if instance[:state] == 'CRASHED'
            result << {
                'instance' => instance[:instance_guid],
                'uptime' => instance[:uptime],
                'since' => instance[:since],
            }
          end
        end

        result

      rescue CloudController::Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      def stats_for_app(process)
        result    = {}
        instances = tps_client.lrp_instances_stats(process)

        for_each_desired_instance(instances, process) do |instance|
          usage = instance[:stats] || {}
          info = {
            state: instance[:state],
            stats: {
              name: process.name,
              uris: process.uris,
              host: instance[:host],
              port: instance[:port],
              net_info: instance[:net_info],
              uptime: instance[:uptime],
              mem_quota:  process[:memory] * 1024 * 1024,
              disk_quota: process[:disk_quota] * 1024 * 1024,
              fds_quota: process.file_descriptors,
              usage: {
                  time: usage[:time] || Time.now.utc.to_s,
                  cpu:  usage[:cpu] || 0,
                  mem:  usage[:mem] || 0,
                  disk: usage[:disk] || 0,
              }
            }
          }
          info[:details] = instance[:details] if instance[:details]
          result[instance[:index]] = info
        end

        fill_unreported_instances_with_down_instances(result, process)
      rescue CloudController::Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      private

      def for_each_desired_instance(instances, process)
        instances.each do |instance|
          next unless instance_is_desired?(instance, process)
          yield(instance)
        end
      end

      def instance_is_desired?(instance, process)
        instance[:index] < process.instances
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

      def logger
        @logger ||= Steno.logger('cc.diego.instances_reporter')
      end
    end
  end
end
