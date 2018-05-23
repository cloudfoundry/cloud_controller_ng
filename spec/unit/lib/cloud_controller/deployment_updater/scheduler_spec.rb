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
      it 'loops, calls update, and sleeps for a given period' do
        expect(DeploymentUpdater::Scheduler).to receive(:loop).and_yield
        expect(DeploymentUpdater::Updater).to receive(:update)
        expect(DeploymentUpdater::Scheduler).to receive(:sleep).with(42)

        DeploymentUpdater::Scheduler.start
      end
    end
  end
end
