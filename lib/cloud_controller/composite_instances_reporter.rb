require "cloud_controller/dea/instances_reporter"
require "cloud_controller/diego/instances_reporter"

module VCAP::CloudController
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
      diego_instances = diego_reporter.number_of_starting_and_running_instances_for_apps(apps_running_on_diego(apps))
      legacy_instances = legacy_reporter.number_of_starting_and_running_instances_for_apps(apps_running_on_dea(apps))

      legacy_instances.merge(diego_instances)
    end

    private

    attr_reader :diego_client, :health_manager_client

    def diego_reporter
      Diego::InstancesReporter.new(diego_client)
    end

    def legacy_reporter
      Dea::InstancesReporter.new(health_manager_client)
    end

    def reporter_for_app(app)
      if app.run_with_diego?
        diego_reporter
      else
        legacy_reporter
      end
    end

    def apps_running_on_diego(apps)
      apps.select(&:run_with_diego?)
    end

    def apps_running_on_dea(apps)
      apps - apps_running_on_diego(apps)
    end
  end
end
