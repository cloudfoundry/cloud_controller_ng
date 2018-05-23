module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      def self.update
        logger = Steno.logger('cc.deployment_updater.update')
        logger.info('run-deployment-update')
      end
    end
  end
end
