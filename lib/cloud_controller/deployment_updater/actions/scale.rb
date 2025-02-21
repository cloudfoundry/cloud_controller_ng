require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'
require 'cloud_controller/deployment_updater/actions/finalize'
require 'cloud_controller/deployment_updater/actions/down_scaler'
require 'cloud_controller/deployment_updater/actions/up_scaler'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Scale
        attr_reader :deployment, :logger, :app, :target_total_instance_count, :interim_desired_instance_count

        def initialize(deployment, logger, target_total_instance_count, interim_desired_instance_count=nil)
          @deployment = deployment
          @logger = logger
          @app = deployment.app
          @target_total_instance_count = target_total_instance_count
          @interim_desired_instance_count = interim_desired_instance_count || target_total_instance_count
        end

        def call
          down_scaler = DownScaler.new(deployment, logger, target_total_instance_count, instance_count_summary.routable_instances_count)
          up_scaler = UpScaler.new(deployment, logger, interim_desired_instance_count, instance_count_summary)

          deployment.db.transaction do
            return unless [DeploymentModel::DEPLOYING_STATE, DeploymentModel::PREPAUSED_STATE].include?(deployment.lock!.state)
            return unless up_scaler.can_scale? || down_scaler.can_downscale?

            app.lock!

            oldest_web_process_with_instances.lock!
            deploying_web_process.lock!

            deployment.update(
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::DEPLOYING_STATUS_REASON
            )

            ScaleDownCanceledProcesses.new(deployment).call

            down_scaler.scale_down if down_scaler.can_downscale?

            return true if up_scaler.finished_scaling?

            up_scaler.scale_up if up_scaler.can_scale?
          end
          false
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        private

        def oldest_web_process_with_instances
          # TODO: lock all web processes?  We might alter all of them, depending on max-in-flight size
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
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
      end
    end
  end
end
