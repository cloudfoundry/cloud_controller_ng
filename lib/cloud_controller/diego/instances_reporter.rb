module VCAP::CloudController
  module Diego
    class InstancesReporter
      attr_reader :diego_client

      def initialize(diego_client)
        @diego_client = diego_client
      end

      def all_instances_for_app(app)
        result    = {}
        instances = diego_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          result[instance[:index]] = {
              state: instance[:state],
              since: instance[:since],
          }
        end

        fill_unreported_instances_with_down_instances(result, app)
      rescue Unavailable => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def number_of_starting_and_running_instances_for_apps(apps)
        apps.each_with_object({}) do |app, result|
          result.update(app.guid => number_of_starting_and_running_instances_for_app(app))
        end
      end

      def number_of_starting_and_running_instances_for_app(app)
        return 0 unless app.started?
        instances = diego_client.lrp_instances(app)

        running_indices = Set.new

        for_each_desired_instance(instances, app) do |instance|
          next unless (instance[:state] == 'RUNNING' || instance[:state] == 'STARTING')
          running_indices.add(instance[:index])
        end

        running_indices.length
      rescue Unavailable => e
        raise Errors::InstancesUnavailable.new(e)
      end

      def crashed_instances_for_app(app)
        result    = []
        instances = diego_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          if instance[:state] == 'CRASHED'
            result << {
                'instance' => instance[:instance_guid],
                'since'    => instance[:since],
            }
          end
        end

        result
      rescue Unavailable => e
        raise Errors::InstancesUnavailable.new(e)
      end

      #TODO: this is only a stub. stats are not yet available from diego.
      def stats_for_app(app)
        result    = {}
        instances = diego_client.lrp_instances(app)

        for_each_desired_instance(instances, app) do |instance|
          result[instance[:index]] = {
              'state' => instance[:state],
              'stats' => {
                  'mem_quota'  => 0,
                  'disk_quota' => 0,
                  'usage'      => {
                      'cpu'  => 0,
                      'mem'  => 0,
                      'disk' => 0,
                  }
              }
          }
        end

        fill_unreported_instances_with_down_instances(result, app)
      rescue Unavailable => e
        raise Errors::InstancesUnavailable.new(e)
      end

      private

      def for_each_desired_instance(instances,app,&blk)
        instances.each do |instance|
          next unless instance_is_desired(instance,app)
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
                since: Time.now.to_i,
            }
          end
        end

        reported_instances
      end
    end
  end
end
