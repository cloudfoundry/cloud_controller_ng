require 'spec_helper'
require 'actions/v2/app_stop'
require 'actions/staging_cancel'

module VCAP::CloudController
  RSpec.describe V2::AppStop do
    let(:cancel_action) { instance_double(StagingCancel, cancel: nil) }

    let(:app) { AppModel.make(desired_state: 'STARTED') }
    let!(:process1) { ProcessModelFactory.make(app: app, state: 'STARTED', type: 'this') }
    let!(:process2) { ProcessModelFactory.make(app: app, state: 'STARTED', type: 'that') }

    before do
      allow(AppStop).to receive(:stop_without_event).and_call_original
    end

    describe '.stop' do
      it 'stops the app and processes by delegating to the V3 AppStop' do
        expect(app.desired_state).to eq('STARTED')
        expect(process1.state).to eq('STARTED')
        expect(process2.state).to eq('STARTED')

        V2::AppStop.stop(app, cancel_action)

        expect(app.reload.desired_state).to eq('STOPPED')
        expect(process1.reload.state).to eq('STOPPED')
        expect(process2.reload.state).to eq('STOPPED')

        expect(AppStop).to have_received(:stop_without_event)
      end

      describe 'when there are builds staging' do
        before { BuildModel.make(app: app, state: BuildModel::STAGING_STATE) }

        it 'does things' do
          V2::AppStop.stop(app, cancel_action)

          expect(cancel_action).to have_received(:cancel) do |builds|
            expect(builds).to match_array(app.builds)
          end
        end
      end
    end
  end
end
