require 'spec_helper'
require 'cloud_controller/diego/staging_guid'

module VCAP::CloudController
  describe Diego::Traditional::StagingCompletionHandler do
    let(:diego) { false }
    let(:staged_app) { App.make(instances: 3, staging_task_id: 'the-staging-task-id', diego: diego) }
    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
    let(:app_id) { staged_app.guid }
    let(:staging_guid) { Diego::StagingGuid.from_app(staged_app) }
    let(:buildpack) { Buildpack.make }

    let(:success_response) do
      {
        result: {
          process_types:      { web: 'some command' },
          execution_metadata: '',
          lifecycle_type:     'buildpack',
          lifecycle_metadata: {
            buildpack_key:      buildpack.key,
            detected_buildpack: 'INTERCAL',
          }
        }
      }
    end

    let(:malformed_success_response) do
      success_response[:result].except(:execution_metadata)
    end

    let(:fail_response) do
      {
        error: { id: 'NoCompatibleCell', message: 'Found no compatible cell' }
      }
    end

    let(:malformed_fail_response) do
      fail_response.except('task_id')
    end

    let(:runner) do
      instance_double(Diego::Runner, start: nil)
    end

    let(:runners) { instance_double(Runners, runner_for_app: runner) }

    subject { Diego::Traditional::StagingCompletionHandler.new(runners) }

    before do
      allow(Steno).to receive(:logger).with('cc.stager').and_return(logger)
      allow(Loggregator).to receive(:emit_error)
      allow(Dea::Client).to receive(:start)

      staged_app.add_new_droplet('lol')
    end

    def handle_staging_result(response)
      subject.staging_complete(staging_guid, response)
    end

    describe 'success cases' do
      it 'marks the app as staged' do
        expect {
          handle_staging_result(success_response)
        }.to change { staged_app.reload.staged? }.to(true)
      end

      context 'when staging metadata is returned' do
        before do
          success_response[:result][:process_types] = {
            web: 'web_command',
            worker: 'worker_command',
            anything: 'lizard hand on a stick'
          }
        end

        it 'updates the droplet with the returned start command' do
          handle_staging_result(success_response)
          staged_app.reload
          droplet = staged_app.current_droplet

          expect(droplet.execution_metadata).to eq('')
          expect(droplet.detected_start_command).to eq('web_command')
          expect(droplet.droplet_hash).to eq('lol')
        end

        context 'when the app has no procfile' do
          before do
            success_response[:result][:process_types] = nil
          end

          it 'gracefully handles a nil process_types' do
            expect {
              handle_staging_result(success_response)
            }.to change { staged_app.reload.staged? }.to(true)
          end
        end
      end

      context 'when the app does not have its diego flag set' do
        it 'starts the app instances' do
          expect(runners).to receive(:runner_for_app) do |received_app|
            expect(received_app.guid).to eq(app_id)
            runner
          end
          expect(runner).to receive(:start)
          handle_staging_result(success_response)
        end

        it 'logs the staging result' do
          handle_staging_result(success_response)
          expect(logger).to have_received(:info).with('diego.staging.finished', response: success_response)
        end

        it 'should update the app with the detected buildpack' do
          handle_staging_result(success_response)
          staged_app.reload
          expect(staged_app.detected_buildpack).to eq('INTERCAL')
          expect(staged_app.detected_buildpack_guid).to eq(buildpack.guid)
        end
      end

      context 'when the app has its diego flag set' do
        let(:diego) { true }

        it 'desires the app using the diego client' do
          expect(runners).to receive(:runner_for_app) do |received_app|
            expect(received_app.guid).to eq(app_id)
            runner
          end
          expect(runner).to receive(:start)
          handle_staging_result(success_response)
        end
      end
    end

    describe 'failure cases' do
      context 'when the staging fails' do
        it "should mark the app as 'failed to stage'" do
          handle_staging_result(fail_response)
          expect(staged_app.reload.package_state).to eq('FAILED')
        end

        it 'records the error' do
          handle_staging_result(fail_response)
          expect(staged_app.reload.staging_failed_reason).to eq('NoCompatibleCell')
        end

        it 'should emit a loggregator error' do
          expect(Loggregator).to receive(:emit_error).with(staged_app.guid, /Found no compatible cell/)
          handle_staging_result(fail_response)
        end

        it 'should not start the app instance' do
          expect(Dea::Client).not_to receive(:start)
          handle_staging_result(fail_response)
        end

        it 'should not update the app with the detected buildpack' do
          handle_staging_result(fail_response)
          staged_app.reload
          expect(staged_app.detected_buildpack).not_to eq('INTERCAL')
          expect(staged_app.detected_buildpack_guid).not_to eq(buildpack.guid)
        end
      end

      context 'when staging with an unknown staging guid' do
        let(:staging_guid) { Diego::StagingGuid.from('unknown_app_guid', 'unknown_task_id') }

        before do
          handle_staging_result(success_response)
        end

        it 'should not attempt to start anything' do
          expect(runner).not_to have_received(:start)
          expect(Dea::Client).not_to have_received(:start)
        end

        it 'logs info for the CF operator since the app may have been deleted by the CF user' do
          expect(logger).to have_received(:error).with('diego.staging.unknown-app', staging_guid: staging_guid)
        end
      end

      context 'with a malformed success message' do
        before do
          expect {
            handle_staging_result(malformed_success_response)
          }.to raise_error(VCAP::Errors::ApiError)
        end

        it 'should not start anything' do
          expect(Dea::Client).not_to have_received(:start)
        end

        it 'logs an error for the CF operator' do
          expect(logger).to have_received(:error).with(
            'diego.staging.success.invalid-message',
            staging_guid: staging_guid,
            payload: malformed_success_response,
            error: '{ result => Missing key }'
          )
        end

        it 'logs an error for the CF user' do
          expect(Loggregator).to have_received(:emit_error).with(staged_app.guid, /Malformed message from Diego stager/)
        end
      end

      context 'with a malformed error message' do
        it 'should not emit any loggregator messages' do
          expect(Loggregator).not_to receive(:emit_error).with(staged_app.guid, /bad/)
          handle_staging_result(malformed_fail_response)
        end
      end

      context 'when updating the app record with data from staging fails' do
        let(:save_error) { StandardError.new('save-error') }

        before do
          allow_any_instance_of(App).to receive(:save_changes).and_raise(save_error)
        end

        it 'should not start anything' do
          handle_staging_result(success_response)

          expect(runners).not_to have_received(:runner_for_app)
          expect(runner).not_to have_received(:start)
        end

        it 'logs an error for the CF operator' do
          handle_staging_result(success_response)

          expect(logger).to have_received(:error).with(
            'diego.staging.saving-staging-result-failed',
            staging_guid: staging_guid,
            response: success_response,
            error: 'save-error',
          )
        end
      end
    end
  end
end
