module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      def self.update
        logger = Steno.logger('cc.deployment_updater.update')
        logger.info('run-deployment-update')

        deployments = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE)

        deployments.each do |deployment|
          scale_deployment(deployment, logger)
        end
      end

      private_class_method

      def self.scale_deployment(deployment, logger)
        app = deployment.app
        web_process = app.web_process
        webish_process = deployment.webish_process

        return unless ready_to_scale?(deployment, logger)

        if web_process.instances == 0
          ProcessModel.db.transaction do
            webish_process.update(type: ProcessTypes::WEB)
            web_process.delete
            webish_process.update(guid: app.guid)

            deployment.update(webish_process: nil, state: DeploymentModel::DEPLOYED_STATE)
          end
        elsif web_process.instances == 1
          web_process.update(instances: web_process.instances - 1)
        else
          ProcessModel.db.transaction do
            web_process.update(instances: web_process.instances - 1)
            webish_process.update(instances: webish_process.instances + 1)
          end
        end

        logger.info("ran-deployment-update-for-#{deployment.guid}")
      end

      def self.ready_to_scale?(deployment, logger)
        instances = instance_reporters.all_instances_for_app(deployment.webish_process)
        instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
      rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
        logger.info("skipping-deployment-update-for-#{deployment.guid}")
        return false
      end

      def self.instance_reporters
        CloudController::DependencyLocator.instance.instances_reporters
      end
    end
  end
end
