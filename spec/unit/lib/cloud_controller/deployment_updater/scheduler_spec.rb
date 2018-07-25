require 'spec_helper'
require 'cloud_controller/deployment_updater/scheduler'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Scheduler do
    before do
      TestConfig.context = :deployment_updater
      TestConfig.override(
        deployment_updater: {
          update_frequency_in_seconds: 42,
        }
      )
    end

    describe '#start' do
      let(:lock_runner) { instance_double(Locket::LockRunner, start: nil, lock_acquired?: nil) }
      let(:lock_worker) { instance_double(Locket::LockWorker) }

      before do
        allow(Locket::LockRunner).to receive(:new).and_return(lock_runner)
        allow(Locket::LockWorker).to receive(:new).and_return(lock_worker)
        allow(lock_worker).to receive(:acquire_lock_and).and_yield
        allow(DeploymentUpdater::Scheduler).to receive(:sleep)
        allow(DeploymentUpdater::Updater).to receive(:update)
      end

      it 'correctly configures a LockRunner and uses it to initialize a LockWorker' do
        DeploymentUpdater::Scheduler.start

        expect(Locket::LockRunner).to have_received(:new).with(
          key: TestConfig.config_instance.get(:deployment_updater, :lock_key),
          owner: TestConfig.config_instance.get(:deployment_updater, :lock_owner),
          host: TestConfig.config_instance.get(:locket, :host),
          port: TestConfig.config_instance.get(:locket, :port),
          client_ca_path: TestConfig.config_instance.get(:locket, :ca_file),
          client_key_path: TestConfig.config_instance.get(:locket, :key_file),
          client_cert_path: TestConfig.config_instance.get(:locket, :cert_file),
        )

        expect(Locket::LockWorker).to have_received(:new).with(lock_runner)
      end

      it 'runs the DeploymentUpdater::Updater sleeps for the configured frequency' do
        DeploymentUpdater::Scheduler.start

        expect(DeploymentUpdater::Updater).to have_received(:update)
        expect(DeploymentUpdater::Scheduler).to have_received(:sleep).with(
          TestConfig.config_instance.get(:deployment_updater, :update_frequency_in_seconds)
        )
      end
    end
  end
end
