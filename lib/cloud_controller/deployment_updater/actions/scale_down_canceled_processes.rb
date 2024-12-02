module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class ScaleDownCanceledProcesses
        attr_reader :deployment

        def initialize(deployment)
          @deployment = deployment
        end

        def call
          superseded_processes.each { |p| p.lock!.update(instances: 0) }
        end

        private

        def superseded_processes
          # Find interim web processes that (a) belong to a SUPERSEDED (CANCELED) deployment and (b) have instances
          # and scale them to zero.
          deployment.app.web_processes_dataset.
            qualify.
            join(:deployments, deploying_web_process_guid: :guid).
            where(deployments__state: DeploymentModel::CANCELED_STATE).
            where(deployments__status_reason: DeploymentModel::SUPERSEDED_STATUS_REASON).
            where(Sequel[:processes__instances] > 0)
        end
      end
    end
  end
end
