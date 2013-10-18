require 'set'

module VCAP::CloudController
  class HM9000Client
    def initialize(config)
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

    def make_request(app)
      client = HTTPClient.new
      uri = "http://#{config[:hm9000_api_host]}:#{config[:hm9000_api_port]}/app"
      client.set_basic_auth(uri, config[:hm9000_api_user], config[:hm9000_api_password])
      response = client.get(uri, query:{"app-guid" => app.guid, "app-version" => app.version})

      if !response.ok?
        return nil
      end

      return JSON.parse(response.body)
    end

    def healthy_instance(app)
      response = make_request(app)

      if !response
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

    attr_reader :config

    def logger
      @logger ||= Steno.logger("cc.healthmanager.client")
    end
  end
end
