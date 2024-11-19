module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class ScaleDownOldProcess
        attr_reader :deployment, :app

        def initialize(deployment)
          @deployment = deployment
          @app = deployment.app
        end

        def call
          process = oldest_web_process_with_instances

          if process.instances <= deployment.max_in_flight && is_interim_process?(process)
            process.destroy
            return
          end

          process.update(instances: [(process.instances - deployment.max_in_flight), 0].max)
        end

        private

        def oldest_web_process_with_instances
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
        end

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
