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
        apps.each_with_object({}) do |app, result|
          result.update(app.guid => number_of_starting_and_running_instances_for_app(app))
        end
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
      rescue Errors::InstancesUnavailable => e
        raise e
      rescue => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def crashed_instances_for_app(app)
        result    = []
        instances = tps_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          if instance[:state] == 'CRASHED'
            result << {
                'instance' => instance[:instance_guid],
                'since'    => instance[:since],
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
              'mem_quota'  => app[:memory] * 1024 * 1024,
              'disk_quota' => app[:disk_quota] * 1024 * 1024,
              'usage'      => {
                  'cpu'  => usage['cpu'] || 0,
                  'mem'  => usage['mem'] || 0,
                  'disk' => usage['disk'] || 0,
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
                since: Time.now.utc.to_i,
            }
          end
        end

        reported_instances
      end
    end
  end
end
