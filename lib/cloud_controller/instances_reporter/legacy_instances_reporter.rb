module VCAP::CloudController::InstancesReporter
  class LegacyInstancesReporter
    attr_reader :health_manager_client

    def initialize(health_manager_client)
      @health_manager_client = health_manager_client
    end

    def all_instances_for_app(app)
      VCAP::CloudController::DeaClient.find_all_instances(app)
    end

    def number_of_starting_and_running_instances_for_app(app)
      return 0 unless app.started?
      health_manager_client.healthy_instances(app)
    end

    def crashed_instances_for_app(app)
      health_manager_client.find_crashes(app)
    end
  end
end