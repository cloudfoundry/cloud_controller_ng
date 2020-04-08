require 'spec_helper'
require 'actions/app_restart'

module VCAP::CloudController
  RSpec.describe AppRestart do
    let(:user_guid) { 'some-guid' }
    let(:user_email) { '1@2.3' }
    let(:config) { nil }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

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
      let!(:process1) { ProcessModel.make(:process, state: desired_state, app: app) }
      let!(:process2) { ProcessModel.make(:process, state: desired_state, app: app) }
      let(:runner) { instance_double(VCAP::CloudController::Diego::Runner) }

      before do
        app.update(droplet: droplet)

        allow(runner).to receive(:stop)
        allow(runner).to receive(:start)

        allow(VCAP::CloudController::Diego::Runner).to receive(:new).and_return(runner)
      end

      it 'does NOT invoke the ProcessObserver after the transaction commits', isolation: :truncation do
        expect(ProcessObserver).not_to receive(:updated)
        AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_restart).with(
          app,
          user_audit_info,
        )
        AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
      end

      context 'when the app is STARTED' do
        before do
          allow(ProcessRestart).
            to receive(:restart).
            with(process: process1, config: config, stop_in_runtime: true, revision: anything).
            and_call_original
          allow(ProcessRestart).
            to receive(:restart).
            with(process: process2, config: config, stop_in_runtime: true, revision: anything).
            and_call_original
        end

        it 'keeps the app state as STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'keeps process states to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)

          expect(process1.reload.state).to eq('STARTED')
          expect(process2.reload.state).to eq('STARTED')
        end

        it 'invokes the ProcessRestart action for each process' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)

          expect(ProcessRestart).
            to have_received(:restart).
            with(process: process1, config: config, stop_in_runtime: true, revision: anything)
          expect(ProcessRestart).
            to have_received(:restart).
            with(process: process2, config: config, stop_in_runtime: true, revision: anything)
        end

        context 'when we need to make a new revision' do
          before do
            app.update(revisions_enabled: true)
            app.update(droplet: DropletModel.make(app: app))

            allow(ProcessRestart).to receive(:restart).and_call_original
            allow(ProcessRestart).to receive(:restart).and_call_original
          end

          it 'creates a revision and associates it to the processes' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to change { RevisionModel.count }.by(1)

            expect(app.reload.desired_state).to eq('STARTED')
            expect(app.reload.latest_revision).not_to be_nil
            expect(app.reload.latest_revision.description).to eq('Initial revision.')
            expect(ProcessRestart).
              to have_received(:restart).
              with(process: process1, config: config, stop_in_runtime: true, revision: app.reload.latest_revision)
            expect(ProcessRestart).
              to have_received(:restart).
              with(process: process2, config: config, stop_in_runtime: true, revision: app.reload.latest_revision)
          end
        end

        it 'generates a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STOPPED').count }.by(2)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end
      end

      context 'when the app is STOPPED' do
        let(:desired_state) { ProcessModel::STOPPED }

        before do
          allow(ProcessRestart).
            to receive(:restart).
            with(process: process1, config: config, stop_in_runtime: false, revision: anything).
            and_call_original
          allow(ProcessRestart).
            to receive(:restart).
            with(process: process2, config: config, stop_in_runtime: false, revision: anything).
            and_call_original
        end

        it 'changes the app state to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'changes the process states to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(process1.reload.reload.state).to eq('STARTED')
          expect(process2.reload.reload.state).to eq('STARTED')
        end

        it 'invokes the ProcessRestart action for each process' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)

          expect(ProcessRestart).
            to have_received(:restart).
            with(process: process1, config: config, stop_in_runtime: false, revision: anything)
          expect(ProcessRestart).
            to have_received(:restart).
            with(process: process2, config: config, stop_in_runtime: false, revision: anything)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end

        it 'does not generate a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to_not change { AppUsageEvent.where(state: 'STOPPED').count }
        end
      end

      context 'when submitting a request to the runtime fails' do
        before do
          allow(ProcessRestart).to receive(:restart).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-diego-error'))
        end

        it 'raises an error and keeps the existing STARTED state' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to raise_error('some-diego-error')

          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'does not generate any additional usage events' do
          original_app_usage_event_count = AppUsageEvent.count
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to raise_error('some-diego-error')

          expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
        end
      end

      context 'when the app is invalid' do
        before do
          allow_any_instance_of(AppModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('apps busted'))
        end

        it 'raises an AppRestart::Error' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to raise_error(AppRestart::Error, 'apps busted')
        end
      end

      context 'when ProcessRestart raises a Sequel::ValidationFailed error' do
        before do
          allow(ProcessRestart).to receive(:restart).and_raise(Sequel::ValidationFailed.new('your process is real bad'))
        end

        it 'raises an AppRestart::Error' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to raise_error(AppRestart::Error, 'your process is real bad')
        end
      end
    end
  end
end
