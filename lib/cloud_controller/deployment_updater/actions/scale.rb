require 'cloud_controller/deployment_updater/actions/scale_down_superseded'
require 'cloud_controller/deployment_updater/actions/scale_down_old_process'
require 'cloud_controller/deployment_updater/actions/finalize'
require 'cloud_controller/deployment_updater/calculators/all_instances_routable'
require 'cloud_controller/deployment_updater/calculators/instances_to_scale_up'
require 'cloud_controller/deployment_updater/calculators/instances_to_scale_down'

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
            return unless Calculators::AllInstancesRoutable.new(deployment, logger).call

            app.lock!
            oldest_web_process_with_instances.lock!
            deploying_web_process.lock!

            instances_to_scale_up = Calculators::InstancesToScaleUp.new(deployment).call
            instances_to_scale_down = Calculators::InstancesToScaleDown.new(deployment, oldest_web_process_with_instances).call

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

            ScaleDownSuperseded.new(deployment).call
            ScaleDownOldProcess.new(deployment, oldest_web_process_with_instances, instances_to_scale_down).call

            deploying_web_process.update(instances: instances_to_scale_up)
          end
        end

        private

        def oldest_web_process_with_instances
          @oldest_web_process_with_instances ||= app.web_processes.select { |process| process.instances > 0 }.min_by { |p| [p.created_at, p.id] }
        end

        def deploying_web_process
          @deploying_web_process ||= deployment.deploying_web_process
        end
      end
    end
  end
end
