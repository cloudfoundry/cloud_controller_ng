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

            prior_web_process = find_interim_web_process || app.oldest_web_process
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

        private

        def find_interim_web_process
          # Find newest interim web process that (a) belongs to a SUPERSEDED (DEPLOYED) deployment and (b) has at least
          # one running instance.
          app.web_processes_dataset.
            qualify.
            join(:deployments, deploying_web_process_guid: :guid).
            where(deployments__state: DeploymentModel::DEPLOYED_STATE).
            where(deployments__status_reason: DeploymentModel::SUPERSEDED_STATUS_REASON).
            order(Sequel.desc(:created_at), Sequel.desc(:id)).
            find { |p| has_running_instance?(p) }
        end

        def has_running_instance?(process)
          instances = instance_reporters.all_instances_for_app(process)
          instances.any? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          false
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
