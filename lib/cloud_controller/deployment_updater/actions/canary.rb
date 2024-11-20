require 'cloud_controller/deployment_updater/actions/scale_down_superseded'
require 'cloud_controller/deployment_updater/calculators/all_instances_routable'

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
            return unless Calculators::AllInstancesRoutable.new(deployment, logger).call

            ScaleDownSuperseded.new(deployment).call

            deployment.update(
              last_healthy_at: Time.now,
              state: DeploymentModel::PAUSED_STATE,
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::PAUSED_STATUS_REASON
            )
            logger.info("paused-canary-deployment-for-#{deployment.guid}")
          end
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
