require 'cloud_controller/deployment_updater/calculators/find_interim_web_process'
module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Cancel
        attr_reader :deployment, :logger, :app, :deploying_web_process

        def initialize(deployment, logger)
          @deployment = deployment
          @logger = logger
          @app = deployment.app
          @deploying_web_process = deployment.deploying_web_process
        end

        def call
          deployment.db.transaction do
            app.lock!
            return unless deployment.lock!.state == DeploymentModel::CANCELING_STATE

            deploying_web_process.lock!

            prior_web_process = Calculators::FindInterimWebProcess.new(deployment).call || app.oldest_web_process
            prior_web_process.lock!

            prior_web_process.update(instances: deployment.original_web_process_instance_count)

            app.web_processes.reject { |p| p.guid == prior_web_process.guid }.map(&:destroy)

            deployment.update(
              state: DeploymentModel::CANCELED_STATE,
              status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
              status_reason: DeploymentModel::CANCELED_STATUS_REASON
            )
          end
        end
      end
    end
  end
end
