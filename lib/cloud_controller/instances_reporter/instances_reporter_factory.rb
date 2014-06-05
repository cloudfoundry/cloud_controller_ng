module VCAP::CloudController::InstancesReporter
  class InstancesReporterFactory
    def initialize(diego_client, health_manager_client)
      @diego_client = diego_client
      @health_manager_client = health_manager_client
    end

    def instances_reporter_for_app(app)
      if diego_client.running_enabled(app)
        DiegoInstancesReporter.new(diego_client)
      else
        LegacyInstancesReporter.new(health_manager_client)
      end
    end

    private

    attr_reader :diego_client, :health_manager_client
  end
end