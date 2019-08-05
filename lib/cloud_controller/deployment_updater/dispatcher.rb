require 'actions/process_restart'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  module DeploymentUpdater
    class Dispatcher
      class << self
        def dispatch
          logger = Steno.logger('cc.deployment_updater.update')
          logger.info('run-deployment-update')

          finalize_degenerate_deployments(logger)

          deployments_to_scale = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE).all
          deployments_to_cancel = DeploymentModel.where(state: DeploymentModel::CANCELING_STATE).all

          begin
            workpool = WorkPool.new(50)

            logger.info("scaling #{deployments_to_scale.size} deployments")
            deployments_to_scale.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                Updater.new(d, l).scale
              end
            end

            logger.info("canceling #{deployments_to_cancel.size} deployments")

            deployments_to_cancel.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                Updater.new(d, l).cancel
              end
            end
          ensure
            workpool.drain
          end
        end

        def finalize_degenerate_deployments(logger)
          DeploymentModel.where(deploying_web_process_guid: nil).each do |d|
            d.update(
              state: DeploymentModel::DEPLOYED_STATE,
              status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
              status_reason: DeploymentModel::DEGENERATE_STATUS_REASON
            )

            logger.warn('finalized-degenerate-deployment', { deployment: d.guid, app: d.app.guid })
          end
        end
      end
    end
  end
end
