require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  module DeploymentUpdater
    class Scheduler
      def self.start
        config = CloudController::DependencyLocator.instance.config

        loop do
          Updater.update
          sleep(config.get(:deployment_updater, :update_frequency_in_seconds))
        end
      end
    end
  end
end
