module VCAP::CloudController
  module DeploymentUpdater
    module Calculators
      class FindInterimWebProcess
        attr_reader :deployment, :app

        def initialize(deployment)
          @deployment = deployment
          @app = deployment.app
        end

        def call
          # Find newest interim web process that (a) belongs to a SUPERSEDED (DEPLOYED) deployment and (b) has at least
          # one running instance.
          app.web_processes_dataset.
            qualify.
            join(:deployments, deploying_web_process_guid: :guid).
            where(deployments__state: DeploymentModel::DEPLOYED_STATE).
            where(deployments__status_reason: DeploymentModel::SUPERSEDED_STATUS_REASON).
            order(Sequel.desc(:created_at), Sequel.desc(:id)).
            find { |p| running_instance?(p) }
        end

        def running_instance?(process)
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
