module VCAP::CloudController
  module Copilot
    class Scheduler
      def self.start
        config = CloudController::DependencyLocator.instance.config

        loop do
          Sync.sync
          sleep(config.get(:copilot, :sync_frequency_in_seconds))
        end
      end
    end
  end
end
