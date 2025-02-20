require 'cloud_controller/deployment_updater/actions/scale'
require 'cloud_controller/deployment_updater/actions/cancel'
require 'cloud_controller/deployment_updater/actions/finalize'

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
          finished = Actions::Scale.new(deployment, logger, deployment.original_web_process_instance_count).call
          Actions::Finalize.new(deployment).call if finished
          logger.info("ran-deployment-update-for-#{deployment.guid}")
        end
      end

      def canary
        with_error_logging('error-canarying-deployment') do
          # TODO: do we need to pass in deployment.original_web_process_instance_count + 1 if there is a single canary instance?
          finished = Actions::Scale.new(deployment, logger, deployment.canary_total_instances, deployment.current_canary_instance_target).call
          if finished
            deployment.update(
              last_healthy_at: Time.now,
              state: DeploymentModel::PAUSED_STATE,
              status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
              status_reason: DeploymentModel::PAUSED_STATUS_REASON
            )
            logger.info("paused-canary-deployment-for-#{deployment.guid}")
          end
          # Actions::Canary.new(deployment, logger).call
          logger.info("ran-canarying-deployment-for-#{deployment.guid}")
        end
      end

      def cancel
        with_error_logging('error-canceling-deployment') do
          Actions::Cancel.new(deployment, logger).call
          logger.info("ran-cancel-deployment-for-#{deployment.guid}")
        end
      end

      private

      def with_error_logging(error_message)
        yield
      rescue StandardError => e
        error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
        logger.error(
          error_message,
          deployment_guid: deployment.guid,
          error: error_name,
          error_message: e.message,
          backtrace: e.backtrace.join("\n")
        )
      end
    end
  end
end
