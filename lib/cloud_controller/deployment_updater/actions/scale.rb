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
            return unless has_space_to_scale?

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

            instances_to_reduce = non_deploying_web_processes.map(&:instances).sum - desired_non_deploying_instances

            if instances_to_reduce > 0

              non_deploying_web_processes.each do |process|
                if instances_to_reduce > process.instances
                  instances_to_reduce -= process.instances
                  ScaleDownOldProcess.new(deployment, process, 0).call
                else
                  ScaleDownOldProcess.new(deployment, process, process.instances - instances_to_reduce).call
                  break
                end
              end
            end
            deploying_web_process.update(instances: desired_new_instances)
          end
        end

        private

        def has_space_to_scale?
          nonroutable_instance_count < deployment.max_in_flight
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def desired_non_deploying_instances
          [deployment.original_web_process_instance_count - routable_instance_count, 0].max
        end

        def desired_new_instances
          [deploying_web_process.instances + deployment.max_in_flight - nonroutable_instance_count, deployment.original_web_process_instance_count].min
        end

        def oldest_web_process_with_instances
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
        end

        def non_deploying_web_processes
          app.web_processes.reject { |process| process.guid == deploying_web_process.guid }.sort_by { |p| [p.created_at, p.id] }
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end

        def routable_instance_count
          reported_instances.select { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }.count
        end

        def nonroutable_instance_count
          reported_instances.reject { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }.count
        end

        def reported_instances
          @reported_instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
