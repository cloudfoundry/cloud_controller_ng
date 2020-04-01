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

          prior_web_process = web_processes.
                              reject { |p| p.guid == deploying_web_process.guid }.
                              max_by(&:created_at)
          prior_web_process.lock!

          prior_web_process.update(instances: deployment.original_web_process_instance_count, type: ProcessTypes::WEB)

          cleanup_web_processes_except(prior_web_process)

          deployment.update(
            state: DeploymentModel::CANCELED_STATE,
            status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
            status_reason: DeploymentModel::CANCELED_STATUS_REASON
          )
        end
      end

      def scale_deployment
        deployment.db.transaction do
          deployment.lock!

          oldest_web_process_with_instances.lock!
          app.lock!
          deploying_web_process.lock!

          return unless ready_to_scale?

          deployment.update(
            last_healthy_at: Time.now,
            state: DeploymentModel::DEPLOYING_STATE,
            status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
            status_reason: DeploymentModel::DEPLOYING_STATUS_REASON,
          )

          if deploying_web_process.instances >= deployment.original_web_process_instance_count
            finalize_deployment
            return
          end

          scale_down_oldest_web_process_with_instances
          deploying_web_process.update(instances: deploying_web_process.instances + 1)
        end
      end

      def app
        @app ||= deployment.app
      end

      def deploying_web_process
        @deploying_web_process ||= deployment.deploying_web_process
      end

      def oldest_web_process_with_instances
        @oldest_web_process_with_instances ||= app.processes.select { |process| process.web? && process.instances > 0 }.min_by(&:created_at)
      end

      def web_processes
        app.processes.select(&:web?)
      end

      def is_original_web_process?(process)
        process == app.oldest_web_process
      end

      def is_interim_process?(process)
        !is_original_web_process?(process)
      end

      def scale_down_oldest_web_process_with_instances
        process = oldest_web_process_with_instances

        if process.instances == 1 && is_interim_process?(process)
          process.destroy
          return
        end

        process.update(instances: process.instances - 1)
      end

      def finalize_deployment
        promote_deploying_web_process

        cleanup_web_processes_except(deploying_web_process)

        update_non_web_processes
        restart_non_web_processes
        deployment.update(
          state: DeploymentModel::DEPLOYED_STATE,
          status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
          status_reason: DeploymentModel::DEPLOYED_STATUS_REASON
        )
      end

      def promote_deploying_web_process
        deploying_web_process.update(type: ProcessTypes::WEB)
      end

      def cleanup_web_processes_except(protected_process)
        web_processes.
          reject { |p| p.guid == protected_process.guid }.
          map(&:destroy)
      end

      def restart_non_web_processes
        app.processes.reject(&:web?).each do |process|
          VCAP::CloudController::ProcessRestart.restart(
            process: process,
            config: Config.config,
            stop_in_runtime: true,
            revision: deploying_web_process.revision,
          )
        end
      end

      def update_non_web_processes
        return if deploying_web_process.revision.nil?

        app.processes.reject(&:web?).each do |process|
          process.update(command: deploying_web_process.revision.commands_by_process_type[process.type])
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
