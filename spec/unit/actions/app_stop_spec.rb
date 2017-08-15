require 'spec_helper'
require 'actions/app_stop'

module VCAP::CloudController
  RSpec.describe AppStop do
    let(:user_guid) { 'diug' }
    let(:user_email) { 'guy@place.io' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

    let(:app) { AppModel.make(desired_state: 'STARTED') }
    let!(:process1) { ProcessModelFactory.make(app: app, state: 'STARTED', type: 'this') }
    let!(:process2) { ProcessModelFactory.make(app: app, state: 'STARTED', type: 'that') }

    describe '#stop' do
      it 'sets the desired state on the app' do
        described_class.stop(app: app, user_audit_info: user_audit_info)
        expect(app.desired_state).to eq('STOPPED')
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_stop).with(
          app,
          user_audit_info,
        )

        described_class.stop(app: app, user_audit_info: user_audit_info)
      end

      it 'prepares the sub-processes of the app' do
        described_class.stop(app: app, user_audit_info: user_audit_info)
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
            described_class.stop(app: app, user_audit_info: user_audit_info)
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
