require 'spec_helper'
require 'actions/app_stop'

module VCAP::CloudController
  describe AppStop do
    let(:app_stop) { AppStop.new(user, user_email) }
    let(:user) { double(:user, guid: 'diug') }
    let(:user_email) { 'guy@place.io' }

    describe '#stop' do
      let(:app_model) { AppModel.make(desired_state: 'STARTED') }
      let(:process1) { AppFactory.make(state: 'STARTED') }
      let(:process2) { AppFactory.make(state: 'STARTED') }

      before do
        app_model.add_process_by_guid(process1.guid)
        app_model.add_process_by_guid(process2.guid)
      end

      it 'sets the desired state on the app' do
        app_stop.stop(app_model)
        expect(app_model.desired_state).to eq('STOPPED')
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_stop).with(
          app_model,
          user.guid,
          user_email
        )

        app_stop.stop(app_model)
      end

      it 'prepares the sub-processes of the app' do
        app_stop.stop(app_model)
        app_model.processes.each do |process|
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
            app_stop.stop(app_model)
          }.to raise_error(AppStop::InvalidApp, 'some message')
        end
      end
    end
  end
end
