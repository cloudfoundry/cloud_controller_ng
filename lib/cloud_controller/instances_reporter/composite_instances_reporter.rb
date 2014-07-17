module VCAP::CloudController::InstancesReporter
  class CompositeInstancesReporter
    def initialize(diego_client, health_manager_client)
      @diego_client = diego_client
      @health_manager_client = health_manager_client
    end

    def number_of_starting_and_running_instances_for_app(app)
      reporter_for_app(app).number_of_starting_and_running_instances_for_app(app)
    end

    def all_instances_for_app(app)
      reporter_for_app(app).all_instances_for_app(app)
    end

    def crashed_instances_for_app(app)
      reporter_for_app(app).crashed_instances_for_app(app)
    end

    def stats_for_app(app)
      reporter_for_app(app).stats_for_app(app)
    end

    def number_of_starting_and_running_instances_for_apps(apps)
      diego_instances = diego_reporter.number_of_starting_and_running_instances_for_apps(diego_apps(apps))
      legacy_instances = legacy_reporter.number_of_starting_and_running_instances_for_apps(legacy_apps(apps))

      legacy_instances.merge(diego_instances)
    end

    private

    attr_reader :diego_client, :health_manager_client

    def diego_reporter
      DiegoInstancesReporter.new(diego_client)
    end

    def legacy_reporter
      LegacyInstancesReporter.new(health_manager_client)
    end

    def reporter_for_app(app)
      if diego_client.running_enabled(app)
        diego_reporter
      else
        legacy_reporter
      end
    end

    def diego_apps(apps)
      apps.select { |app| diego_client.running_enabled(app) }
    end

    def legacy_apps(apps)
      apps - diego_apps(apps)
    end
  end
end
