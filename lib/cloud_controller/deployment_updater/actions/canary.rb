require 'cloud_controller/deployment_updater/actions/scale_down_canceled'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Canary
        attr_reader :deployment, :logger

        def initialize(deployment, logger)
          @deployment = deployment
          @logger = logger
        end

        def call
          deployment.db.transaction do
            deployment.lock!
            return unless deployment.state == DeploymentModel::PREPAUSED_STATE
            return unless all_instances_routable?

            ScaleDownCanceled.new(deployment).call

            deployment.update(
              last_healthy_at: Time.now,
              state: DeploymentModel::PAUSED_STATE,
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::PAUSED_STATUS_REASON
            )
            logger.info("paused-canary-deployment-for-#{deployment.guid}")
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
      end
    end
  end
end
