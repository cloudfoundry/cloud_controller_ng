require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'
require 'cloud_controller/deployment_updater/actions/scale_down_old_process'
require 'cloud_controller/deployment_updater/actions/finalize'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Scale
        attr_reader :deployment, :logger, :app

        def initialize(deployment, logger)
          @deployment = deployment
          @logger = logger
          @app = deployment.app
        end

        def call
          deployment.db.transaction do
            return unless deployment.lock!.state == DeploymentModel::DEPLOYING_STATE
            return unless all_instances_routable?

            app.lock!
            oldest_web_process_with_instances.lock!
            deploying_web_process.lock!

            deployment.update(
              last_healthy_at: Time.now,
              state: DeploymentModel::DEPLOYING_STATE,
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::DEPLOYING_STATUS_REASON
            )

            if deploying_web_process.instances >= deployment.original_web_process_instance_count
              Finalize.new(deployment).call
              return
            end

            ScaleDownCanceledProcesses.new(deployment).call
            ScaleDownOldProcess.new(deployment, oldest_web_process_with_instances, desired_old_instances).call

            deploying_web_process.update(instances: desired_new_instances)
          end
        end

        private

        def desired_old_instances
          [(oldest_web_process_with_instances.instances - deployment.max_in_flight), 0].max
        end

        def desired_new_instances
          [deploying_web_process.instances + deployment.max_in_flight, deployment.original_web_process_instance_count].min
        end

        def oldest_web_process_with_instances
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end

        def all_instances_routable?
          instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
          instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
