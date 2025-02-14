module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class UpScaler
        attr_reader :deployment, :logger, :app, :interim_desired_instance_count

        def initialize(deployment, logger, interim_desired_instance_count, instance_count_summary)
          @deployment = deployment
          @app = deployment.app
          @logger = logger
          @interim_desired_instance_count = interim_desired_instance_count
          @starting_instances_count = instance_count_summary.starting_instances_count
          @unhealthy_instances_count = instance_count_summary.unhealthy_instances_count
          @routable_instances_count = instance_count_summary.routable_instances_count
        end

        def scale_up
          return unless can_scale?

          deploying_web_process.update(instances: desired_new_instances)
          deployment.update(last_healthy_at: Time.now)
        end

        def can_scale?
          @starting_instances_count < deployment.max_in_flight &&
            @unhealthy_instances_count == 0 &&
            # if routable instances is < deploying_web_process.instances - deployment.max_in_flight
            # then that indicates that Diego isnt in sync with CAPI yet
            @routable_instances_count >= deploying_web_process.instances - deployment.max_in_flight
        end

        def finished_scaling?
          deploying_web_process.instances >= interim_desired_instance_count
        end

        private

        def desired_new_instances
          [@routable_instances_count + deployment.max_in_flight, interim_desired_instance_count].min
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end
      end
    end
  end
end
