require 'cloud_controller/deployment_updater/actions/cleanup_web_processes'
module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Finalize
        attr_reader :deployment, :deploying_web_process, :app

        def initialize(deployment)
          @deployment = deployment
          @app = deployment.app
          @deploying_web_process = deployment.deploying_web_process
        end

        def call
          CleanupWebProcesses.new(deployment, deploying_web_process).call

          update_non_web_processes
          restart_non_web_processes
          deployment.update(
            state: DeploymentModel::DEPLOYED_STATE,
            status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
            status_reason: DeploymentModel::DEPLOYED_STATUS_REASON
          )
        end

        private

        def update_non_web_processes
          return if deploying_web_process.revision.nil?

          app.processes.reject(&:web?).each do |process|
            process.update(command: deploying_web_process.revision.commands_by_process_type[process.type])
          end
        end

        def restart_non_web_processes
          app.processes.reject(&:web?).each do |process|
            VCAP::CloudController::ProcessRestart.restart(
              process: process,
              config: Config.config,
              stop_in_runtime: true,
              revision: deploying_web_process.revision
            )
          end
        end
      end
    end
  end
end
