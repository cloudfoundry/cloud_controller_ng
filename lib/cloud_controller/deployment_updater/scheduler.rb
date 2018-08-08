require 'cloud_controller/deployment_updater/updater'
require 'locket/lock_worker'
require 'locket/lock_runner'

module VCAP::CloudController
  module DeploymentUpdater
    class Scheduler
      class << self
        def start
          config = CloudController::DependencyLocator.instance.config
          lock_runner = Locket::LockRunner.new(
            key: config.get(:deployment_updater, :lock_key),
            owner: config.get(:deployment_updater, :lock_owner),
            host: config.get(:locket, :host),
            port: config.get(:locket, :port),
            client_ca_path: config.get(:locket, :ca_file),
            client_key_path: config.get(:locket, :key_file),
            client_cert_path: config.get(:locket, :cert_file),
          )
          statsd_client = CloudController::DependencyLocator.instance.statsd_client

          lock_worker = Locket::LockWorker.new(lock_runner)

          lock_worker.acquire_lock_and do
            update(
              update_frequency: config.get(:deployment_updater, :update_frequency_in_seconds),
              statsd_client: statsd_client
            )
          end
        end

        private

        def update(update_frequency:, statsd_client:)
          logger = Steno.logger('cc.deployment_updater.scheduler')

          update_start_time = Time.now
          statsd_client.time('cc.deployments.update.duration') do
            Updater.update
          end
          update_duration = Time.now - update_start_time
          logger.info("Update loop took #{update_duration}s")

          sleep_duration = update_frequency - update_duration
          if sleep_duration > 0
            logger.info("Sleeping #{sleep_duration}s")
            sleep(sleep_duration)
          else
            logger.info('Not Sleeping')
          end
        end
      end
    end
  end
end
