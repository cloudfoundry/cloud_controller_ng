require 'spec_helper'
require 'actions/app_restart'

module VCAP::CloudController
  RSpec.describe AppRestart, isolation: :truncation do
    let(:user_guid) { 'some-guid' }
    let(:user_email) { '1@2.3' }
    let(:config) { nil }

    describe '#restart' do
      let(:environment_variables) { { 'FOO' => 'bar' } }
      let(:desired_state) { ProcessModel::STARTED }
      let(:app) do
        AppModel.make(
          :docker,
          desired_state:         desired_state,
          environment_variables: environment_variables
        )
      end

      VCAP::CloudController::FeatureFlag.make(name: 'diego_docker',
                                              enabled: true, error_message: nil)
      let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }

      let!(:droplet) { DropletModel.make(app: app) }
      let!(:process1) { ProcessModel.make(:process, state: desired_state, app: app) }
      let!(:process2) { ProcessModel.make(:process, state: desired_state, app: app) }
      let(:runner1) { instance_double(VCAP::CloudController::Diego::Runner) }
      let(:runner2) { instance_double(VCAP::CloudController::Diego::Runner) }

      before do
        app.update(droplet: droplet)

        allow(runner1).to receive(:stop)
        allow(runner1).to receive(:start)
        allow(runner2).to receive(:stop)
        allow(runner2).to receive(:start)

        allow(VCAP::CloudController::Diego::Runner).to receive(:new) do |process, _|
          process.guid == process1.guid ? runner1 : runner2
        end
      end

      context 'when the app is STARTED' do
        it 'keeps the app state as STARTED' do
          AppRestart.restart(app: app, config: config)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'keeps process states to STARTED' do
          AppRestart.restart(app: app, config: config)
          expect(process1.reload.state).to eq('STARTED')
          expect(process2.reload.state).to eq('STARTED')
        end

        it 'stops running processes in the runtime' do
          expect(runner1).to receive(:stop).once
          expect(runner2).to receive(:stop).once

          AppRestart.restart(app: app, config: config)
        end

        it 'starts running processes in the runtime' do
          expect(runner1).to receive(:start).once
          expect(runner2).to receive(:start).once

          AppRestart.restart(app: app, config: config)
        end

        it 'generates a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config)
          }.to change { AppUsageEvent.where(state: 'STOPPED').count }.by(2)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end

        context 'when submitting the stop request to the backend fails' do
          before do
            allow(runner1).to receive(:stop).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-stop-error'))
            allow(runner2).to receive(:stop).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-stop-error'))
          end

          it 'raises an error and keeps the existing STARTED state' do
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error('some-stop-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(runner1).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
            allow(runner2).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end

      context 'when the app is STOPPED' do
        let(:desired_state) { ProcessModel::STOPPED }

        it 'changes the app state to STARTED' do
          AppRestart.restart(app: app, config: config)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'changes the process states to STARTED' do
          AppRestart.restart(app: app, config: config)
          expect(process1.reload.reload.state).to eq('STARTED')
          expect(process2.reload.reload.state).to eq('STARTED')
        end

        it 'does NOT attempt to stop running processes in the runtime' do
          expect(runner1).to_not receive(:stop)
          expect(runner2).to_not receive(:stop)

          AppRestart.restart(app: app, config: config)
        end

        it 'starts running processes in the runtime' do
          expect(runner1).to receive(:start).once
          expect(runner2).to receive(:start).once

          AppRestart.restart(app: app, config: config)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end

        it 'does not generate a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config)
          }.to_not change { AppUsageEvent.where(state: 'STOPPED').count }
        end

        context 'when the app is invalid' do
          before do
            allow_any_instance_of(AppModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
          end

          it 'raises an AppRestart::Error' do
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error(AppRestart::Error, 'some message')
          end
        end

        context 'when the process is invalid' do
          before do
            allow_any_instance_of(ProcessModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
          end

          it 'raises an AppRestart::Error' do
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error(AppRestart::Error, 'some message')
          end
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(runner1).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
            allow(runner2).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STOPPED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              AppRestart.restart(app: app, config: config)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end
    end
  end
end
