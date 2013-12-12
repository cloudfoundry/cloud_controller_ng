require 'set'

module VCAP::CloudController
  class HM9000Client
    def initialize(message_bus, config)
      @message_bus = message_bus
      @config = config
    end

    def healthy_instances(app_or_apps)
      if app_or_apps.kind_of?(Array)
        apps = app_or_apps
        result = {}
        apps.each do |app|
          result[app.guid] = healthy_instance(app)
        end
        return result
      else
        app = app_or_apps
        return healthy_instance(app)
      end
    end

    def find_crashes(app)
      response = make_request(app)
      if !response
        return []
      end

      crashing_instances = []
      response["instance_heartbeats"].each do |instance|
        if instance["state"] == "CRASHED"
          crashing_instances << {"instance" => instance["instance"], "since" => instance["state_timestamp"]}
        end
      end

      return crashing_instances
    end

    def find_flapping_indices(app)
      response = make_request(app)
      if !response
        return []
      end

      flapping_indices = []

      response["crash_counts"].each do |crash_count|
        if crash_count["crash_count"] >= @config[:flapping_crash_count_threshold]
          flapping_indices << {"index" => crash_count["instance_index"], "since" => crash_count["created_at"]}
        end
      end

      return flapping_indices
    end

    private

    def healthy_instance(app)
      response = make_request(app)

      if response.nil? || response["instance_heartbeats"].nil?
        return 0
      end

      running_indices = Set.new
      response["instance_heartbeats"].each do |instance|
        if instance["index"] < app.instances && (instance["state"] == "RUNNING" || instance["state"] == "STARTING")
          running_indices.add(instance["index"])
        end
      end

      return running_indices.length
    end

    def make_request(app)
      responses = @message_bus.synchronous_request("app.state", { droplet: app.guid, version: app.version }, { timeout: 2 })
      return if responses.empty?

      response = responses.first
      return if response.empty?

      response
    end

    def logger
      @logger ||= Steno.logger("cc.healthmanager.client")
    end
  end
end
