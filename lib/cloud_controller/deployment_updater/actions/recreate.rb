require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'
require 'cloud_controller/deployment_updater/actions/finalize'
require 'cloud_controller/deployment_updater/actions/down_scaler'
require 'cloud_controller/deployment_updater/actions/up_scaler'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Recreate
        attr_reader :deployment, :logger, :app, :target_total_instance_count, :interim_desired_instance_count

        def initialize(deployment, logger, target_total_instance_count, interim_desired_instance_count=nil)
          @deployment = deployment
          @logger = logger
          @app = deployment.app
          @target_total_instance_count = target_total_instance_count
          @interim_desired_instance_count = interim_desired_instance_count || target_total_instance_count
        end

        def call
          logger.info("RECREATE Starting down scaler #{deployment.guid}")
          down_scaler = DownScaler.new(deployment, logger, target_total_instance_count, instance_count_summary.routable_instances_count)
          logger.info("RECREATE starting db transaction for #{deployment.guid}")
          deployment.db.transaction do
            return unless [DeploymentModel::DEPLOYING_STATE, DeploymentModel::PREPAUSED_STATE].include?(deployment.lock!.state)
            return unless can_scale? || down_scaler.can_downscale?

            logger.info("RECREATE lock the app for #{deployment.guid}")
            app.lock!
            logger.info("RECREATE lock the web_processes for #{deployment.guid}")
            app.web_processes.each(&:lock!)
            logger.info("RECREATE set status to active/deploying for #{deployment.guid}")
            deployment.update(
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::DEPLOYING_STATUS_REASON,
              error: nil
            )
            logger.info("RECREATE scale down canceled processes for #{deployment.guid}")
            ScaleDownCanceledProcesses.new(deployment).call
            logger.info("RECREATE scale down web processes for #{deployment.guid}")
            down_scaler.scale_down if down_scaler.can_downscale?
            logger.info("are we finished scaling for #{deployment.guid}")
            return true if finished_scaling?

            logger.info("not finished scaling, scaling up web processes  for #{deployment.guid}")
            scale_up if can_scale?
          end
          false
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        private

        def scale_up
          return unless can_scale?

          deploying_web_process.update(instances: desired_new_instances)
          deployment.update(last_healthy_at: Time.now)
        end

        def instance_count_summary
          @instance_count_summary ||= instance_reporters.instance_count_summary(deploying_web_process)
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end

        def can_scale
          deploying_web_process.instances < interim_desired_instance_count && @routable_instances_count < interim_desired_instance_count
        end

        def finished_scaling
          deploying_web_process.instances >= interim_desired_instance_count && @routable_instances_count >= interim_desired_instance_count
        end
      end
    end
  end
end
