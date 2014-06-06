module VCAP::CloudController::InstancesReporter
  class DiegoInstancesReporter
    attr_reader :diego_client

    def initialize(diego_client)
      @diego_client = diego_client
    end

    def all_instances_for_app(app)
      result    = {}
      instances = diego_client.lrp_instances(app)

      instances.each do |instance|
        result[instance[:index]] = {
          state: instance[:state],
          since: instance[:since],
        }
      end

      result
    end

    def number_of_starting_and_running_instances_for_app(app)
      return 0 unless app.started?
      instances = diego_client.lrp_instances(app)

      running_indices = Set.new

      instances.each do |instance|
        if instance_is_desired(instance, app) && (instance[:state] == 'RUNNING' || instance[:state] == 'STARTING')
          running_indices.add(instance[:index])
        end
      end

      running_indices.length
    end

    def crashed_instances_for_app(app)
      result    = []
      instances = diego_client.lrp_instances(app)

      instances.each do |instance|
        if instance[:state] == 'CRASHED'
          result << {
            'instance' => instance[:instance_guid],
            'since'    => instance[:since],
          }
        end
      end

      result
    end

    #TODO: this is only a stub. stats are not yet available from diego.
    def stats_for_app(app, opts)
      result    = {}
      instances = diego_client.lrp_instances(app)
      instances.each do |instance|
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

      result
    end

    private

    def instance_is_desired(instance, app)
      instance[:index] < app.instances
    end
  end
end