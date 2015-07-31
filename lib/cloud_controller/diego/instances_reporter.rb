module VCAP::CloudController
  module Diego
    class InstancesReporter
      attr_reader :tps_client

      def initialize(tps_client)
        @tps_client = tps_client
      end

      def all_instances_for_app(app)
        result    = {}
        instances = tps_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          info = {
            state: instance[:state],
            uptime: instance[:uptime],
            since: instance[:since],
          }
          info[:details] = instance[:details] if instance[:details]
          result[instance[:index]] = info
        end

        fill_unreported_instances_with_down_instances(result, app)
      rescue Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def number_of_starting_and_running_instances_for_apps(apps)
        result = {}

        instances_map = tps_client.bulk_lrp_instances(apps)
        apps.each do |application|
          running_indices = Set.new

          for_each_desired_instance(instances_map[application.guid.to_sym] || [], application) do |instance|
            next unless instance[:state] == 'RUNNING' || instance[:state] == 'STARTING'
            running_indices.add(instance[:index])
          end

          result[application.guid] = running_indices.length
        end

        result
      rescue Errors::InstancesUnavailable
        apps.each { |application| result[application.guid] = -1 }
        result
      rescue => e
        logger.error('tps.error', error: e.to_s)
        apps.each { |application| result[application.guid] = -1 }
        result
      end

      def number_of_starting_and_running_instances_for_app(app)
        return 0 unless app.started?
        instances = tps_client.lrp_instances(app)

        running_indices = Set.new

        for_each_desired_instance(instances, app) do |instance|
          next unless instance[:state] == 'RUNNING' || instance[:state] == 'STARTING'
          running_indices.add(instance[:index])
        end

        running_indices.length
      rescue Errors::InstancesUnavailable
        return -1
      rescue => e
        logger.error('tps.error', error: e.to_s)
        return -1
      end

      def crashed_instances_for_app(app)
        result    = []
        instances = tps_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          if instance[:state] == 'CRASHED'
            result << {
                'instance' => instance[:instance_guid],
                'uptime' => instance[:uptime],
                'since' => instance[:since],
            }
          end
        end

        result

      rescue Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def stats_for_app(app)
        result    = {}
        instances = tps_client.lrp_instances_stats(app)

        for_each_desired_instance(instances, app) do |instance|
          usage = instance[:stats] || {}
          info = {
            'state' => instance[:state],
            'stats' => {
              'name' => app.name,
              'uris' => app.uris,
              'host' => instance[:host],
              'port' => instance[:port],
              'uptime' => instance[:uptime],
              'mem_quota'  => app[:memory] * 1024 * 1024,
              'disk_quota' => app[:disk_quota] * 1024 * 1024,
              'fds_quota' => app.file_descriptors,
              'usage'      => {
                  'time'  => usage[:time] || Time.now.utc.to_s,
                  'cpu'  => usage[:cpu] || 0,
                  'mem'  => usage[:mem] || 0,
                  'disk' => usage[:disk] || 0,
              }
            }
          }
          info['details'] = instance[:details] if instance[:details]
          result[instance[:index]] = info
        end

        fill_unreported_instances_with_down_instances(result, app)

      rescue Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise Errors::InstancesUnavailable.new(e)
      end

      private

      def for_each_desired_instance(instances, app, &blk)
        instances.each do |instance|
          next unless instance_is_desired(instance, app)
          blk.call(instance)
        end
      end

      def instance_is_desired(instance, app)
        instance[:index] < app.instances
      end

      def fill_unreported_instances_with_down_instances(reported_instances, app)
        app.instances.times do |i|
          unless reported_instances[i]
            reported_instances[i] = {
                state: 'DOWN',
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
