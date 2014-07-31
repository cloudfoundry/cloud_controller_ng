require "cloud_controller/dea/backend"
require "cloud_controller/diego/backend"

module VCAP::CloudController
  class Backends
    def initialize(message_bus, diego_client)
      @message_bus = message_bus
      @diego_client = diego_client
    end

    def find_one_to_run(app)
      if @diego_client.running_enabled(app)
        Diego::Backend.new(app, @diego_client)
      else
        Dea::Backend.new(app, @message_bus)
      end
    end
  end
end
