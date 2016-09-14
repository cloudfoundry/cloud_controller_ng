require 'spec_helper'
require 'actions/app_stop'

module VCAP::CloudController
  RSpec.describe AppStop do
    let(:user_guid) { 'diug' }
    let(:user_email) { 'guy@place.io' }

    let(:app) { AppModel.make(desired_state: 'STARTED') }
    let!(:process1) { AppFactory.make(app: app, state: 'STARTED', type: 'this') }
    let!(:process2) { AppFactory.make(app: app, state: 'STARTED', type: 'that') }

    describe '#stop' do
      it 'sets the desired state on the app' do
        described_class.stop(app: app, user_guid: user_guid, user_email: user_email)
        expect(app.desired_state).to eq('STOPPED')
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_stop).with(
          app,
          user_guid,
          user_email
        )

        described_class.stop(app: app, user_guid: user_guid, user_email: user_email)
      end

      it 'prepares the sub-processes of the app' do
        described_class.stop(app: app, user_guid: user_guid, user_email: user_email)
        app.processes.each do |process|
          expect(process.started?).to eq(false)
          expect(process.state).to eq('STOPPED')
        end
      end

      context 'when the app is invalid' do
        before do
          allow_any_instance_of(AppModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
        end

        it 'raises a InvalidApp exception' do
          expect {
            described_class.stop(app: app, user_guid: user_guid, user_email: user_email)
          }.to raise_error(AppStop::InvalidApp, 'some message')
        end
      end
    end

    describe '#stop_without_event' do
      it 'sets the desired state on the app' do
        described_class.stop_without_event(app)
        expect(app.desired_state).to eq('STOPPED')
      end

      it 'does not record an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).not_to receive(:record_app_stop)
        described_class.stop_without_event(app)
      end
    end
  end
end
