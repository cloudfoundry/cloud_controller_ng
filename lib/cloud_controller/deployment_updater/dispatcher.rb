require 'actions/process_restart'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  module DeploymentUpdater
    class Dispatcher
      class << self
        def dispatch
          logger = Steno.logger('cc.deployment_updater.update')
          logger.info('run-deployment-update')

          deployments_to_scale = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE).all
          deployments_to_cancel = DeploymentModel.where(state: DeploymentModel::CANCELING_STATE).all
          deployments_to_canary = DeploymentModel.where(state: DeploymentModel::PREPAUSED_STATE).all

          begin
            workpool = WorkPool.new(50)

            logger.info("scaling #{deployments_to_scale.size} deployments")
            deployments_to_scale.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                Updater.new(d, l).scale
              end
            end

            logger.info("canarying #{deployments_to_canary.size} deployments")
            deployments_to_canary.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                Updater.new(d, l).canary
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
      end
    end
  end
end
