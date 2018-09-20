module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      attr_reader :deployment, :logger

      def initialize(deployment, logger)
        @deployment = deployment
        @logger = logger
      end

      def scale
        with_error_logging('error-scaling-deployment') do
          scale_deployment
          logger.info("ran-deployment-update-for-#{deployment.guid}")
        end
      end

      def cancel
        with_error_logging('error-canceling-deployment') do
          cancel_deployment
          logger.info("ran-cancel-deployment-for-#{deployment.guid}")
        end
      end

      private

      def with_error_logging(error_message)
        yield
      rescue => e
        error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
        logger.error(
          error_message,
            deployment_guid: deployment.guid,
            error: error_name,
            error_message: e.message,
            backtrace: e.backtrace.join("\n")
        )
      end

      def cancel_deployment
        deployment.db.transaction do
          deployment.lock!

          app.lock!
          deploying_web_process.lock!

          prior_webish_process = app.processes.
                                 select(&:web?).
                                 reject { |p| p.guid == deploying_web_process.guid }.
                                 max_by(&:created_at)
          prior_webish_process.lock!

          prior_webish_process.update(instances: deployment.original_web_process_instance_count, type: 'web')

          cleanup_webish_processes_except(prior_webish_process)

          deployment.update(state: DeploymentModel::CANCELED_STATE)
        end
      end

      def scale_deployment
        deployment.db.transaction do
          deployment.lock!

          oldest_web_process.lock!
          app.lock!
          deploying_web_process.lock!

          return unless ready_to_scale?

          if deploying_web_process.instances >= deployment.original_web_process_instance_count
            finalize_deployment
            return
          end

          scale_down_oldest_web_process
          deploying_web_process.update(instances: deploying_web_process.instances + 1)
        end
      end

      def app
        @app ||= deployment.app
      end

      def deploying_web_process
        @deploying_web_process ||= deployment.deploying_web_process
      end

      def oldest_web_process
        @oldest_web_process ||= app.oldest_webish_process
      end

      def scale_down_oldest_web_process
        if oldest_web_process.instances > 1
          oldest_web_process.update(instances: oldest_web_process.instances - 1)
        else
          cleanup_webish_process(oldest_web_process)
        end
      end

      def cleanup_webish_process(process)
        if process.type != 'web'
          RouteMappingModel.where(app: app, process_type: process.type).map(&:destroy)
        end
        process.destroy
      end

      def finalize_deployment
        promote_deploying_web_process

        cleanup_webish_processes_except(deploying_web_process)

        restart_non_web_processes
        deployment.update(state: DeploymentModel::DEPLOYED_STATE)
      end

      def promote_deploying_web_process
        RouteMappingModel.where(app: deploying_web_process.app,
                                process_type: deploying_web_process.type).map(&:destroy)
        deploying_web_process.update(type: ProcessTypes::WEB)
        oldest_web_process.destroy
      end

      def cleanup_webish_processes_except(protected_process)
        app.processes.
          select(&:web?).
          reject { |p| p.guid == protected_process.guid }.
          each { |p| cleanup_webish_process(p) }
      end

      def restart_non_web_processes
        app.processes.reject(&:web?).each do |process|
          VCAP::CloudController::ProcessRestart.restart(process: process, config: Config.config, stop_in_runtime: true)
        end
      end

      def ready_to_scale?
        instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
        instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
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
