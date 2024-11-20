module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class CleanupWebProcesses
        attr_reader :deployment, :app, :protected_process

        def initialize(deployment, process)
          @deployment = deployment
          @app = deployment.app
          @protected_process = process
        end

        def call
          app.web_processes.
            reject { |p| p.guid == protected_process.guid }.
            map(&:destroy)
        end
      end
    end
  end
end
