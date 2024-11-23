module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class ScaleDownOldProcess
        attr_reader :deployment, :process, :app, :instances_to_scale_down

        def initialize(deployment, process, instances_to_scale_down)
          @deployment = deployment
          @app = deployment.app
          @process = process
          @instances_to_scale_down = instances_to_scale_down
        end

        def call
          if process.instances <= instances_to_scale_down && is_interim_process?(process)
            process.destroy
            return
          end

          process.update(instances: instances_to_scale_down)
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
