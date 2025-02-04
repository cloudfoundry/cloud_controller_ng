require 'cloud_controller/deployment_updater/actions/scale_down_old_process'
module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class DownScaler
        attr_reader :deployment, :logger, :app, :target_total_instance_count

        def initialize(deployment, logger, target_total_instance_count, routable_instance_count)
          @deployment = deployment
          @app = deployment.app
          @logger = logger
          @target_total_instance_count = target_total_instance_count
          @routable_instance_count = routable_instance_count
        end

        def scale_down
          instances_to_reduce = non_deploying_web_processes.map(&:instances).sum - desired_non_deploying_instances

          return if instances_to_reduce <= 0

          non_deploying_web_processes.each do |process|
            if instances_to_reduce < process.instances
              ScaleDownOldProcess.new(deployment, process, process.instances - instances_to_reduce).call
              break
            end

            instances_to_reduce -= process.instances
            ScaleDownOldProcess.new(deployment, process, 0).call
          end
        end

        def can_downscale?
          non_deploying_web_processes.map(&:instances).sum > desired_non_deploying_instances
        end

        def desired_non_deploying_instances
          [target_total_instance_count - @routable_instance_count, 0].max
        end

        private

        def non_deploying_web_processes
          app.web_processes.reject { |process| process.guid == deployment.deploying_web_process.guid }.sort_by { |p| [p.created_at, p.id] }
        end
      end
    end
  end
end
