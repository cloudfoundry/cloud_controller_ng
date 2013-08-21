module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    def initialize(config = Config.config, message_bus = Config.message_bus)
      @config = config
      @message_bus = message_bus
    end

    def health_manager_client
      @health_manager_client ||= HealthManagerClient.new(config, message_bus)
    end

    def task_client
      @task_client ||= TaskClient.new(message_bus)
    end

    private

    attr_reader :config, :message_bus
  end
end
