module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class ScaleDownOldProcess
        attr_reader :deployment, :process, :app, :desired_instances

        def initialize(deployment, process, desired_instances)
          @deployment = deployment
          @app = deployment.app
          @process = process
          @desired_instances = desired_instances
        end

        def call
          if desired_instances == 0 && is_interim_process?(process)
            process.destroy
            return
          end

          process.update(instances: desired_instances)
        end

        private

        def is_original_web_process?(process)
          process == app.oldest_web_process
        end

        def is_interim_process?(process)
          !is_original_web_process?(process)
        end
      end
    end
  end
end
