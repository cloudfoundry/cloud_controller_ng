require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'
require 'cloud_controller/deployment_updater/actions/scale_down_old_process'
require 'cloud_controller/deployment_updater/actions/finalize'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module DeploymentUpdater
    module Actions
      class Scale
        HEALTHY_STATES = [VCAP::CloudController::Diego::LRP_RUNNING, VCAP::CloudController::Diego::LRP_STARTING].freeze
        attr_reader :deployment, :logger, :app, :target_total_instance_count, :interim_desired_instance_count

        def initialize(deployment, logger, target_total_instance_count, interim_desired_instance_count = nil)
          @deployment = deployment
          @logger = logger
          @app = deployment.app
          @target_total_instance_count = target_total_instance_count
          @interim_desired_instance_count = interim_desired_instance_count || target_total_instance_count
        end

        def call
          deployment.db.transaction do
            return unless deployment.lock!.state == DeploymentModel::DEPLOYING_STATE

            return unless can_scale? || can_downscale?

            app.lock!

            oldest_web_process_with_instances.lock!
            deploying_web_process.lock!

            deployment.update(
              state: DeploymentModel::DEPLOYING_STATE,
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::DEPLOYING_STATUS_REASON
            )
            
            ScaleDownCanceledProcesses.new(deployment).call

            scale_down_old_processes if can_downscale?

            return true if deploying_web_process.instances >= interim_desired_instance_count

            if can_scale?
              deploying_web_process.update(instances: desired_new_instances)
              deployment.update(last_healthy_at: Time.now)
            end
          end
          false
        end

        private

        def scale_down_old_processes
          instances_to_reduce = non_deploying_web_processes.map(&:instances).sum - desired_non_deploying_instances

          return if instances_to_reduce <= 0

          non_deploying_web_processes.each do |process|
            if instances_to_reduce < process.instances
              ScaleDownOldProcess.new(deployment, process, process.instances - instances_to_reduce).call
              break
            end

            instances_to_reduce -= process.instances
            ScaleDownOldProcess.new(deployment, process, 0).call
          end
        end

        def can_scale?
          starting_instances.count < deployment.max_in_flight &&
            unhealthy_instances.count == 0 &&
            routable_instances.count >= deploying_web_process.instances - deployment.max_in_flight
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def can_downscale?
          non_deploying_web_processes.map(&:instances).sum > desired_non_deploying_instances
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def desired_non_deploying_instances
          [target_total_instance_count - routable_instances.count, 0].max
        end

        def desired_new_instances
          [routable_instances.count + deployment.max_in_flight, interim_desired_instance_count].min
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

        def starting_instances
          healthy_instances.reject { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        end

        def routable_instances
          reported_instances.select { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        end

        def healthy_instances
          reported_instances.select { |_, val| HEALTHY_STATES.include?(val[:state]) }
        end

        def unhealthy_instances
          reported_instances.reject { |_, val| HEALTHY_STATES.include?(val[:state]) }
        end

        def reported_instances
          @reported_instances = instance_reporters.all_instances_for_app(deploying_web_process)
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
