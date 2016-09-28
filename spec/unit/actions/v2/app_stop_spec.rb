require 'spec_helper'
require 'actions/v2/app_stop'

module VCAP::CloudController
  RSpec.describe V2::AppStop do
    let(:stagers) { instance_double(Stagers) }
    let(:stager) { instance_double(Diego::Stager) }

    let(:app) { AppModel.make(desired_state: 'STARTED') }
    let!(:process1) { AppFactory.make(app: app, state: 'STARTED', type: 'this') }
    let!(:process2) { AppFactory.make(app: app, state: 'STARTED', type: 'that') }

    before do
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      allow(stager).to receive(:stop_stage)
      allow(AppStop).to receive(:stop_without_event).and_call_original
    end

    describe '.stop' do
      it 'stops the app and processes by delegating to the V3 AppStop' do
        expect(app.desired_state).to eq('STARTED')
        expect(process1.state).to eq('STARTED')
        expect(process2.state).to eq('STARTED')

        V2::AppStop.stop(app, stagers)

        expect(app.reload.desired_state).to eq('STOPPED')
        expect(process1.reload.state).to eq('STOPPED')
        expect(process2.reload.state).to eq('STOPPED')

        expect(AppStop).to have_received(:stop_without_event)
      end

      describe 'when there are droplets staging' do
        let!(:staging_droplet1) { DropletModel.make(app: app, state: DropletModel::STAGING_STATE) }
        let!(:staging_droplet2) { DropletModel.make(app: app, state: DropletModel::STAGING_STATE) }
        let!(:staged_droplet) { DropletModel.make(app: app, state: DropletModel::STAGED_STATE) }
        let!(:staging_droplet_on_another_app) { DropletModel.make(state: DropletModel::STAGING_STATE) }

        it 'sends a stop staging request for staging droplets' do
          V2::AppStop.stop(app, stagers)

          expect(stagers).to have_received(:stager_for_app).with(app)
          expect(stager).to have_received(:stop_stage).with(staging_droplet1.guid)
          expect(stager).to have_received(:stop_stage).with(staging_droplet2.guid)
          expect(stager).not_to have_received(:stop_stage).with(staging_droplet_on_another_app.guid)
        end

        it 'does NOT send a stop staging request for staged droplets' do
          V2::AppStop.stop(app, stagers)

          expect(stager).to_not have_received(:stop_stage).with(staged_droplet.guid)
        end
      end
    end
  end
end
