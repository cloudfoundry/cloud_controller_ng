require 'cloud_controller/deployment_updater/dispatcher'
require 'locket/lock_worker'
require 'locket/client'

module VCAP::CloudController
  module DeploymentUpdater
    class Scheduler
      class << self
        def start
          with_error_logging('cc.deployment_updater') do
            config = CloudController::DependencyLocator.instance.config
            statsd_client = CloudController::DependencyLocator.instance.statsd_client
            prometheus_updater = CloudController::DependencyLocator.instance.prometheus_updater

            update_step = proc { update(
              update_frequency: config.get(:deployment_updater, :update_frequency_in_seconds),
              statsd_client: statsd_client,
              prometheus_updater: prometheus_updater
            )
            }

            locket_client = Locket::Client.new(
              host: config.get(:locket, :host),
              port: config.get(:locket, :port),
              client_ca_path: config.get(:locket, :ca_file),
              client_key_path: config.get(:locket, :key_file),
              client_cert_path: config.get(:locket, :cert_file),
            )
            lock_worker = Locket::LockWorker.new(locket_client)
            lock_worker.acquire_lock_and_repeatedly_call(
              owner: config.get(:deployment_updater, :lock_owner),
              key: config.get(:deployment_updater, :lock_key),
              &update_step
            )
          end
        end

        private

        def update(update_frequency:, statsd_client:, prometheus_updater:)
          logger = Steno.logger('cc.deployment_updater.scheduler')

          update_start_time = Time.now
          Dispatcher.dispatch
          update_duration = Time.now - update_start_time
          ## NOTE: We're taking time in seconds and multiplying by 1000 because we don't have
          ##       access to time in milliseconds. If you ever get access to reliable time in
          ##       milliseconds, then do know that the lack of precision here is not desired
          ##       so feed in the entire value!
          update_duration_ms = update_duration * 1000
          statsd_client.timing('cc.deployments.update.duration', update_duration_ms)
          prometheus_updater.report_deployment_duration(update_duration_ms)

          logger.info("Update loop took #{update_duration}s")

          sleep_duration = update_frequency - update_duration
          if sleep_duration > 0
            logger.info("Sleeping #{sleep_duration}s")
            sleep(sleep_duration)
          else
            logger.info('Not Sleeping')
          end
        end

        def with_error_logging(error_message)
          yield
        rescue => e
          logger = Steno.logger('cc.deployment_updater')
          error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
          logger.error(
            error_message,
            error: error_name,
            error_message: e.message,
            backtrace: e.backtrace.join("\n"),
          )
        end
      end
    end
  end
end
