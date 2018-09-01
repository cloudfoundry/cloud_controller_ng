require 'actions/process_restart'

module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      class << self
        def update
          logger = Steno.logger('cc.deployment_updater.update')
          logger.info('run-deployment-update')

          deployments_to_scale = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE).all
          deployments_to_cancel = DeploymentModel.where(state: DeploymentModel::CANCELING_STATE).all

          begin
            workpool = WorkPool.new(50)

            logger.info("scaling #{deployments_to_scale.size} deployments")
            deployments_to_scale.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                begin
                  scale_deployment(d, l)
                rescue => e
                  error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
                  logger.error(
                    'error-scaling-deployment',
                    deployment_guid: d.guid,
                    error: error_name,
                    error_message: e.message,
                    backtrace: e.backtrace.join("\n")
                  )
                end
              end
            end

            logger.info("canceling #{deployments_to_cancel.size} deployments")
            deployments_to_cancel.each do |deployment|
              workpool.submit(deployment, logger) do |d, l|
                begin
                  cancel_deployment(d, l)
                rescue => e
                  error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
                  logger.error(
                    'error-canceling-deployment',
                    deployment_guid: d.guid,
                    error: error_name,
                    error_message: e.message,
                    backtrace: e.backtrace.join("\n")
                  )
                end
              end
            end
          ensure
            workpool.drain
          end
        end

        private

        def scale_deployment(deployment, logger)
          deployment.db.transaction do
            deployment.lock!

            app = deployment.app
            original_web_process = app.web_process
            deploying_web_process = deployment.deploying_web_process

            app.lock!
            original_web_process.lock!
            deploying_web_process.lock!

            return unless ready_to_scale?(deployment, logger)

            case original_web_process.instances
            when 0 # deploying web process is fully scaled
              promote_deploying_web_process(deploying_web_process, original_web_process)

              restart_non_web_processes(app)
              deployment.update(state: DeploymentModel::DEPLOYED_STATE)
            when 1 # do not increment deploying web process because upon deploy, an initial deploying web process was created
              original_web_process.update(instances: original_web_process.instances - 1)
            else
              original_web_process.update(instances: original_web_process.instances - 1)
              deploying_web_process.update(instances: deploying_web_process.instances + 1)
            end
          end

          logger.info("ran-deployment-update-for-#{deployment.guid}")
        end

        def cancel_deployment(deployment, logger)
          deployment.db.transaction do
            deployment.lock!

            app = deployment.app
            original_web_process = app.web_process
            deploying_web_process = deployment.deploying_web_process

            app.lock!
            original_web_process.lock!
            deploying_web_process.lock!

            original_web_process.update(
              instances: infer_original_instance_count(original_web_process, deploying_web_process)
            )

            RouteMappingModel.where(app: app, process_type: deploying_web_process.type).map(&:destroy)
            deploying_web_process.destroy
            deployment.update(state: DeploymentModel::CANCELED_STATE)
            logger.info("ran-cancel-deployment-for-#{deployment.guid}")
          end
        end

        def infer_original_instance_count(original_web_process, deploying_web_process)
          if original_web_process.instances <= 1
            deploying_web_process.instances
          else
            original_web_process.instances + deploying_web_process.instances - 1
          end
        end

        def ready_to_scale?(deployment, logger)
          instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
          instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end

        def promote_deploying_web_process(deploying_web_process, original_web_process)
          RouteMappingModel.where(app: deploying_web_process.app,
                                  process_type: deploying_web_process.type).map(&:destroy)
          deploying_web_process.update(type: ProcessTypes::WEB)
          original_web_process.destroy
        end

        def restart_non_web_processes(app)
          app.processes.reject(&:web?).each do |process|
            VCAP::CloudController::ProcessRestart.restart(process: process, config: Config.config, stop_in_runtime: true)
          end
        end
      end
    end
  end
end
