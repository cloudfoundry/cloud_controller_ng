require 'cloud_controller/deployment_updater/updater'
require 'locket/lock_worker'
require 'locket/lock_runner'

module VCAP::CloudController
  module DeploymentUpdater
    class Scheduler
      def self.start
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

        lock_worker = Locket::LockWorker.new(lock_runner)

        lock_worker.acquire_lock_and do
          Updater.update
          sleep(config.get(:deployment_updater, :update_frequency_in_seconds))
        end
      end
    end
  end
end
