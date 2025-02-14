require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/down_scaler'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::DownScaler do
    # subject(:scale_action) { DeploymentUpdater::Actions::DownScaler.new(deployment, logger, target_total_instance_count) }

    let(:app) { AppModel.make(droplet: droplet, revisions_enabled: true) }
    let(:droplet) { DropletModel.make }

    let!(:web_process) do
      ProcessModel.make(
        instances: 3,
        created_at: 1.day.ago,
        guid: 'guid-original',
        app: app
      )
    end

    let!(:interim_web_process) do
      ProcessModel.make(
        instances: 1,
        created_at: 3.hours.ago,
        guid: 'guid-interim',
        app: app
      )
    end

    let!(:interim_web_process_2) do
      ProcessModel.make(
        instances: 2,
        created_at: 2.hours.ago,
        guid: 'guid-interim-2',
        app: app
      )
    end

    let!(:deploying_web_process) do
      ProcessModel.make(
        app: web_process.app,
        type: ProcessTypes::WEB,
        instances: 4,
        guid: 'guid-final',
        state: ProcessModel::STOPPED
      )
    end

    let(:deployment) do
      DeploymentModel.make(
        app: web_process.app,
        deploying_web_process: deploying_web_process,
        state: DeploymentModel::DEPLOYING_STATE
      )
    end

    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }

    describe '#can_downscale?' do
      it 'returns true if desired_non_deploying_instances is less than sum of non_deploying_web_processes instance' do
        down_scaler = DeploymentUpdater::Actions::DownScaler.new(deployment, logger, 10, 5)
        expect(down_scaler.desired_non_deploying_instances).to eq 5
        expect(down_scaler.can_downscale?).to be true
      end

      it 'returns false if desired_non_deploying_instances is more than sum of non_deploying_web_processes instance' do
        down_scaler = DeploymentUpdater::Actions::DownScaler.new(deployment, logger, 10, 4)
        expect(down_scaler.desired_non_deploying_instances).to eq 6
        expect(down_scaler.can_downscale?).to be false
      end
    end

    describe '#scale_down' do
      it 'scales down to desired_non_deploying_instances, starting with the oldest web process' do
        down_scaler = DeploymentUpdater::Actions::DownScaler.new(deployment, logger, 10, 5)

        expect(web_process.instances).to eq(3)
        expect(interim_web_process.instances).to eq(1)

        down_scaler.scale_down

        web_process.reload
        interim_web_process.reload

        expect(web_process.instances).to eq(2)
        expect(interim_web_process.instances).to eq(1)
      end

      it 'does not delete the original web process' do
        down_scaler = DeploymentUpdater::Actions::DownScaler.new(deployment, logger, 10, 7)

        expect(web_process.instances).to eq(3)
        expect(interim_web_process.instances).to eq(1)

        down_scaler.scale_down

        web_process.reload
        interim_web_process.reload

        expect(web_process.instances).to eq(0)
        expect(interim_web_process.instances).to eq(1)
      end

      it 'does delete interim web processes' do
        down_scaler = DeploymentUpdater::Actions::DownScaler.new(deployment, logger, 10, 8)

        expect(web_process.instances).to eq(3)
        expect(interim_web_process.instances).to eq(1)

        down_scaler.scale_down

        web_process.reload

        expect(web_process.instances).to eq(0)
        expect { interim_web_process.reload }.to raise_error(Sequel::NoExistingObject)
      end
    end
  end
end
