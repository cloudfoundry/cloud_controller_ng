require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/up_scaler'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::UpScaler do
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
        instances: current_instance_count,
        guid: 'guid-final',
        state: ProcessModel::STOPPED
      )
    end

    let(:deployment) do
      DeploymentModel.make(
        app: web_process.app,
        deploying_web_process: deploying_web_process,
        state: DeploymentModel::DEPLOYING_STATE,
        max_in_flight: max_in_flight
      )
    end

    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }
    let(:current_instance_count) { 4 }
    let(:max_in_flight) { 2 }

    describe '#can_scale?' do
      let(:current_instance_count) { 4 }
      let(:max_in_flight) { 2 }

      it 'returns true if it has enough max-in-flight to scale' do
        summary = double(starting_instances_count: 1, routable_instances_count: 5, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(up_scaler.can_scale?).to be true
      end

      it 'returns false if there are any unhealthy instances' do
        summary = double(starting_instances_count: 1, routable_instances_count: 5, healthy_instances_count: nil, unhealthy_instances_count: 1)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(up_scaler.can_scale?).to be false
      end

      it 'returns false if starting instances >= max_in_flight' do
        summary = double(starting_instances_count: 2, routable_instances_count: 5, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(up_scaler.can_scale?).to be false
      end

      it 'returns false if routable instances already exceeds target' do
        skip('Might need to restructure the scale action if we do this')
        summary = double(starting_instances_count: 0, routable_instances_count: 5, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 4, summary)
        expect(up_scaler.can_scale?).to be false
      end
    end

    describe '#finished_scaling?' do
      let(:current_instance_count) { 5 }

      it 'returns true if current instances have reached the target number of instances' do
        summary = double(starting_instances_count: 0, routable_instances_count: 5, healthy_instances_count: 5, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 5, summary)
        expect(up_scaler.finished_scaling?).to be true
      end

      it 'returns false if current instances have not reached the target number of instances' do
        summary = double(starting_instances_count: 0, routable_instances_count: 5, healthy_instances_count: 5, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 6, summary)
        expect(up_scaler.finished_scaling?).to be false
      end

      it 'returns false if number of routable instances does not match desired instances' do
        summary = double(starting_instances_count: 0, routable_instances_count: 4, healthy_instances_count: 5, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 5, summary)
        expect(up_scaler.finished_scaling?).to be false
      end

      it 'returns true if there are any unhealthy instances but we have already reached the target' do
        summary = double(starting_instances_count: 0, routable_instances_count: 5, healthy_instances_count: 5, unhealthy_instances_count: 1)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 5, summary)
        expect(up_scaler.finished_scaling?).to be true
      end

      it 'returns true if there are any starting instances but we have already reached the target' do
        summary = double(starting_instances_count: 1, routable_instances_count: 5, healthy_instances_count: 5, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 5, summary)
        expect(up_scaler.finished_scaling?).to be true
      end
    end

    describe '#scale_up' do
      let(:current_instance_count) { 4 }
      let(:max_in_flight) { 2 }

      it 'scales up max_in_flight amount if there is space' do
        summary = double(starting_instances_count: 0, routable_instances_count: 4, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(6)
      end

      it 'does not scale up if max_in_flight instances are currently starting' do
        summary = double(starting_instances_count: 2, routable_instances_count: 5, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(4)
      end

      it 'scales up the difference between starting instances and max_in_flight if some instances are starting' do
        summary = double(starting_instances_count: 1, routable_instances_count: 3, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(5)
      end

      context 'with high max_in_flight' do
        let(:max_in_flight) { 20 }

        it 'only scales up to the passed in interim_desired_instance_count' do
          summary = double(starting_instances_count: 0, routable_instances_count: 9, healthy_instances_count: nil, unhealthy_instances_count: 0)
          up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
          expect(deploying_web_process.instances).to eq(4)
          up_scaler.scale_up
          expect(deploying_web_process.reload.instances).to eq(10)
        end
      end

      it 'corrects + scales deploying web process instances if there are more routable + starting instances than specified on the model' do
        summary = double(starting_instances_count: 1, routable_instances_count: 6, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(8)
      end

      it 'does nothing if there are unhealthy instances' do
        summary = double(starting_instances_count: 0, routable_instances_count: 3, healthy_instances_count: nil, unhealthy_instances_count: 1)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(4)
      end

      it 'does nothing if routable instances are missing' do
        summary = double(starting_instances_count: 0, routable_instances_count: 1, healthy_instances_count: nil, unhealthy_instances_count: 0)
        up_scaler = DeploymentUpdater::Actions::UpScaler.new(deployment, logger, 10, summary)
        expect(deploying_web_process.instances).to eq(4)
        up_scaler.scale_up
        expect(deploying_web_process.reload.instances).to eq(4)
      end
    end
  end
end
