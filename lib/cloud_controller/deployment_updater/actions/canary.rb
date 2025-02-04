require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Canary
        HEALTHY_STATES = [VCAP::CloudController::Diego::LRP_RUNNING, VCAP::CloudController::Diego::LRP_STARTING].freeze
        attr_reader :deployment, :app, :logger

        def initialize(deployment, logger)
          @deployment = deployment
          @app = deployment.app
          @logger = logger
        end

        def call
          deployment.db.transaction do
            deployment.lock!
          return unless deployment.state == DeploymentModel::PREPAUSED_STATE
            # return unless all_instances_routable?


            interim_desired_instance_count = deployment.canary_step[:canary]

            logger.info("interim_desired_instance_count-#{interim_desired_instance_count}")
#       
            down_scaler = DownScaler.new(deployment, logger, deployment.original_web_process_instance_count + 1, routable_instances.count)
            up_scaler = UpScaler.new(deployment, logger, interim_desired_instance_count, routable_instances.count, starting_instances.count, unhealthy_instances.count)

            return unless up_scaler.can_scale? || down_scaler.can_downscale?

            app.lock! # Do we need this ?

            oldest_web_process_with_instances.lock!
            deploying_web_process.lock!

            down_scaler.scale_down if down_scaler.can_downscale?

            up_scaler.scale_up if up_scaler.can_scale?

            # done with the step
            ScaleDownCanceledProcesses.new(deployment).call
            # todo should down_scaler.is_done? be a thing here?
            # todo this should check that the instances are actually running.
            if deploying_web_process.instances >= interim_desired_instance_count 

              deployment.update(
                last_healthy_at: Time.now,
                state: DeploymentModel::PAUSED_STATE,
                status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
                status_reason: DeploymentModel::PAUSED_STATUS_REASON
              )
              logger.info("paused-canary-deployment-for-#{deployment.guid}")
            end
          end
        end

        private

        def all_instances_routable?
          instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
          instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-canary-update-for-#{deployment.guid}")
          false
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end

        def starting_instances
          healthy_instances.reject { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        end

        def routable_instances
          reported_instances.select { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        end

        def healthy_instances
          reported_instances.select { |_, val| HEALTHY_STATES.include?(val[:state]) }
        end

        def unhealthy_instances
          reported_instances.reject { |_, val| HEALTHY_STATES.include?(val[:state]) }
        end
        
        def reported_instances
          @reported_instances = instance_reporters.all_instances_for_app(deploying_web_process)
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end

        def oldest_web_process_with_instances
          #should we lock all web processes?
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
        end
      end
    end
  end
end
