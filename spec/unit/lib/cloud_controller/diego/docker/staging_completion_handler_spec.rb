require 'spec_helper'
require 'cloud_controller/diego/docker/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Docker
      describe StagingCompletionHandler do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
        let(:runner) { instance_double(Diego::Runner, start: nil) }
        let(:runners) { instance_double(Runners, runner_for_app: runner) }
        let(:app) { AppFactory.make(staging_task_id: 'fake-staging-task-id') }
        let(:payload) { {} }

        subject(:handler) { StagingCompletionHandler.new(runners) }

        before do
          allow(Steno).to receive(:logger).with('cc.docker.stager').and_return(logger)
          allow(Loggregator).to receive(:emit_error)
        end

        context 'when it receives a success response' do
          let(:payload) do
            {
              'app_id' => app.guid,
              'task_id' => app.staging_task_id
            }
          end

          it 'marks the app as staged' do
            expect {
              handler.staging_complete(payload)
            }.to change {
              app.reload.staged?
            }.from(false).to(true)
          end

          it 'sends desires the app on Diego' do
            handler.staging_complete(payload)

            expect(runners).to have_received(:runner_for_app).with(app)
            expect(runner).to have_received(:start)
          end

          context 'when it receives execution metadata' do
            let(:payload) do
              {
                'app_id' => app.guid,
                'task_id' => app.staging_task_id,
                'execution_metadata' => '"{\"cmd\":[\"start\"]}"',
                'detected_start_command' => { 'web' => 'start' },
              }
            end

            it 'creates a droplet with the metadata' do
              handler.staging_complete(payload)

              app.reload
              expect(app.current_droplet.execution_metadata).to eq('"{\"cmd\":[\"start\"]}"')
              expect(app.current_droplet.detected_start_command).to eq('start')
            end
          end

          context 'when the app_id is invalid' do
            let(:payload) do
              {
                'app_id' => 'bad-app-id'
              }
            end

            it 'returns without sending a desire request for the app' do
              handler.staging_complete(payload)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end

            it 'logs info about an unknown app for the CF operator' do
              handler.staging_complete(payload)

              expect(logger).to have_received(:error).with(
                'diego.docker.staging.unknown-app',
                response: payload
              )
            end
          end

          context 'when the task_id is invalid' do
            let(:payload) do
              {
                'app_id' => app.guid,
                'task_id' => 'bad-task-id'
              }
            end

            it 'returns without sending a desired request for the app' do
              handler.staging_complete(payload)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end

            it 'logs info about an invalid task id for the CF operator and returns' do
              handler.staging_complete(payload)

              expect(logger).to have_received(:warn).with(
                'diego.docker.staging.not-current',
                response: payload,
                current: app.staging_task_id
              )
            end
          end

          context 'when updating the app table with data from staging fails' do
            let(:payload) do
              {
                'app_id' => app.guid,
                'task_id' => app.staging_task_id,
              }
            end
            let(:save_error) { StandardError.new('save-error') }

            before do
              allow_any_instance_of(App).to receive(:save_changes).and_raise(save_error)
            end

            it 'should not start anything' do
              handler.staging_complete(payload)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end

            it 'logs an error for the CF operator' do
              handler.staging_complete(payload)

              expect(logger).to have_received(:error).with(
                'diego.docker.staging.saving-staging-result-failed',
                response: payload,
                error: 'save-error',
              )
            end
          end
        end

        context 'when it receives a failure response' do
          let(:payload) do
            {
              'app_id' => app.guid,
              'task_id' => app.staging_task_id,
              'error' => 'fake-error',
            }
          end

          it 'marks the app as failed to stage' do
            expect {
              handler.staging_complete(payload)
            }.to change {
              app.reload.package_state
            }.from('PENDING').to('FAILED')
          end

          it 'logs an error for the CF user' do
            handler.staging_complete(payload)

            expect(Loggregator).to have_received(:emit_error).with(app.guid, /fake-error/)
          end

          it 'returns without sending a desired request for the app' do
            handler.staging_complete(payload)

            expect(runners).not_to have_received(:runner_for_app)
            expect(runner).not_to have_received(:start)
          end
        end
      end
    end
  end
end
