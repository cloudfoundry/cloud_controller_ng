require 'spec_helper'
require 'actions/process_restart'

module VCAP::CloudController
  RSpec.describe ProcessRestart do
    let(:config) { nil }

    describe '.restart' do
      let(:environment_variables) { { 'FOO' => 'bar' } }
      let(:desired_state) { ProcessModel::STARTED }
      let(:app) do
        AppModel.make(
          :docker,
          desired_state:         desired_state,
          environment_variables: environment_variables
        )
      end

      let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }

      let!(:droplet) { DropletModel.make(app: app) }
      let!(:process) { ProcessModel.make(:process, state: desired_state, app: app) }
      let(:runner) { instance_double(VCAP::CloudController::Diego::Runner) }

      before do
        app.update(droplet: droplet)

        allow(runner).to receive(:stop)
        allow(runner).to receive(:start)

        allow(VCAP::CloudController::Diego::Runner).to receive(:new).and_return(runner)
      end

      it 'does NOT invoke the ProcessObserver after the transaction commits', isolation: :truncation do
        expect(ProcessObserver).not_to receive(:updated)
        ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
      end

      context 'when the process is STARTED' do
        it 'keeps process state as STARTED' do
          ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
          expect(process.reload.state).to eq('STARTED')
        end

        it 'stops running the process in the runtime' do
          expect(runner).to receive(:stop).once

          ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
        end

        it 'starts running the process in the runtime' do
          expect(runner).to receive(:start).once

          ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
        end

        it 'generates a STOP usage event' do
          expect {
            ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
          }.to change { AppUsageEvent.where(state: 'STOPPED').count }.by(1)
        end

        it 'generates a START usage event' do
          expect {
            ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(1)
        end

        context 'when submitting the stop request to the backend fails' do
          before do
            allow(runner).to receive(:stop).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-stop-error'))
          end

          it 'raises an error and keeps the existing STARTED state' do
            expect {
              ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
            }.to raise_error('some-stop-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              ProcessRestart.restart(process: process, config: config, stop_in_runtime: true)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end

      context 'when the process is STOPPED' do
        let(:desired_state) { ProcessModel::STOPPED }

        it 'changes the process states to STARTED' do
          ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
          expect(process.reload.reload.state).to eq('STARTED')
        end

        it 'does NOT attempt to stop the process in the runtime' do
          expect(runner).to_not receive(:stop)

          ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
        end

        it 'starts running the process in the runtime' do
          expect(runner).to receive(:start).once

          ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
        end

        it 'generates a START usage event' do
          expect {
            ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(1)
        end

        it 'does not generate a STOP usage event' do
          expect {
            ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
          }.to_not change { AppUsageEvent.where(state: 'STOPPED').count }
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STOPPED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end

      context 'revision to set' do
        let(:revision) { RevisionModel.make }

        it 'sets the revision of the process if passed in' do
          ProcessRestart.restart(process: process, config: config, stop_in_runtime: false, revision: revision)

          expect(process.reload.revision).to eq(revision)
        end

        it 'leaves the old revision if not passed in' do
          process.update(revision: revision)

          ProcessRestart.restart(process: process, config: config, stop_in_runtime: false)

          expect(process.reload.revision).to eq(revision)
        end
      end
    end
  end
end
