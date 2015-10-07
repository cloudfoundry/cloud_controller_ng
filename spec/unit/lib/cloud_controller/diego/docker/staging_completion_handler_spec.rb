require 'spec_helper'
require 'cloud_controller/diego/staging_guid'
require 'cloud_controller/diego/docker/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Docker
      describe StagingCompletionHandler do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
        let(:runner) { instance_double(Diego::Runner, start: nil) }
        let(:runners) { instance_double(Runners, runner_for_app: runner) }
        let(:app) { AppFactory.make(staging_task_id: 'fake-staging-task-id') }
        let(:staging_guid) { Diego::StagingGuid.from_app(app) }
        let(:payload) { {} }

        subject(:handler) { StagingCompletionHandler.new(runners) }

        before do
          allow(Steno).to receive(:logger).with('cc.docker.stager').and_return(logger)
          allow(Loggregator).to receive(:emit_error)
        end

        context 'when it receives a success response' do
          let(:payload) do
            {
              result: {
                execution_metadata: '"{\"cmd\":[\"start\"]}"',
                process_types: { web: 'start' },
                lifecycle_type: 'docker',
                lifecycle_metadata: {
                  docker_image: docker_image_name
                }
              }
            }
          end
          let(:docker_image_name) { '' }

          it 'marks the app as staged' do
            expect {
              handler.staging_complete(staging_guid, payload)
            }.to change {
              app.reload.staged?
            }.from(false).to(true)
          end

          it 'sends desires the app on Diego' do
            handler.staging_complete(staging_guid, payload)

            expect(runners).to have_received(:runner_for_app).with(app)
            expect(runner).to have_received(:start)
          end

          describe 'lifecycle_metadata in response' do
            let(:droplet) { app.reload.current_droplet }

            context 'with cached image' do
              let(:docker_image_name) { '10.244.2.6:8080/generated_id:latest' }

              it 'updates the app with the new image' do
                handler.staging_complete(staging_guid, payload)

                expect(droplet.cached_docker_image).to eq(docker_image_name)
              end
            end

            context 'with empty cached image' do
              let(:docker_image_name) { '' }

              it 'does not update the cached image' do
                handler.staging_complete(staging_guid, payload)

                expect(droplet.cached_docker_image).to be_nil
              end
            end
          end

          context 'when the app is restaged and user opted-out from caching' do
            let(:payload) do
              {
                result: {
                  execution_metadata: '"{\"cmd\":[\"start\"]}"',
                  process_types:      { web: 'start' },
                  lifecycle_type:     'docker',
                  lifecycle_metadata: {
                    docker_image: ''
                  }
                }
              }
            end
            let(:droplet) { app.reload.current_droplet }

            before do
              FeatureFlag.create(name: 'diego_docker', enabled: true)
            end

            context 'when image was cached' do
              let(:app) { AppFactory.make(staging_task_id: 'fake-staging-task-id', docker_image: 'user_provided') }

              before { app.current_droplet.cached_docker_image = 'cached' }

              it 'clears the cached_docker_image' do
                handler.staging_complete(staging_guid, payload)

                app.reload
                expect(droplet.cached_docker_image).to be_nil
              end
            end
          end

          context 'when it receives execution metadata' do
            it 'creates a droplet with the metadata' do
              handler.staging_complete(staging_guid, payload)

              app.reload
              expect(app.current_droplet.execution_metadata).to eq('"{\"cmd\":[\"start\"]}"')
              expect(app.current_droplet.detected_start_command).to eq('start')
            end
          end

          context 'when process_types is empty' do
            before do
              payload[:result][:process_types] = nil
            end

            it 'raises ApiError and marks the app as failed to stage' do
              expect {
                handler.staging_complete(staging_guid, payload)
              }.to raise_error(VCAP::Errors::ApiError).and change {
                app.reload.package_state
              }.from('PENDING').to('FAILED')
            end

            it 'logs an error for the CF operator' do
              expect {
                handler.staging_complete(staging_guid, payload)
              }.to raise_error(VCAP::Errors::ApiError)

              expect(logger).to have_received(:error).with(
                'diego.staging.success.invalid-message',
                staging_guid: staging_guid,
                payload: payload,
                error: '{ result => { process_types => Expected instance of Hash, given instance of NilClass. } }'
              )
            end

            it 'logs an error for the CF user' do
              expect {
                handler.staging_complete(staging_guid, payload)
              }.to raise_error(VCAP::Errors::ApiError)

              expect(Loggregator).to have_received(:emit_error).with(app.guid, /Malformed message from Diego stager/)
            end

            it 'should not start anything' do
              expect {
                handler.staging_complete(staging_guid, payload)
              }.to raise_error(VCAP::Errors::ApiError)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end
          end

          context 'when the staging guid is invalid' do
            let(:staging_guid) { Diego::StagingGuid.from('unknown_app_guid', 'unknown_task_id') }

            it 'returns without sending a desire request for the app' do
              handler.staging_complete(staging_guid, payload)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end

            it 'logs info about an unknown app for the CF operator' do
              handler.staging_complete(staging_guid, payload)

              expect(logger).to have_received(:error).with(
                'diego.docker.staging.unknown-app',
                staging_guid: staging_guid
              )
            end
          end

          context 'when updating the app table with data from staging fails' do
            let(:save_error) { StandardError.new('save-error') }

            before do
              allow_any_instance_of(App).to receive(:save_changes).and_raise(save_error)
            end

            it 'should not start anything' do
              handler.staging_complete(staging_guid, payload)

              expect(runners).not_to have_received(:runner_for_app)
              expect(runner).not_to have_received(:start)
            end

            it 'logs an error for the CF operator' do
              handler.staging_complete(staging_guid, payload)

              expect(logger).to have_received(:error).with(
                'diego.docker.staging.saving-staging-result-failed',
                staging_guid: staging_guid,
                response: payload,
                error: 'save-error',
              )
            end
          end
        end

        context 'when it receives a failure response' do
          let(:payload) do
            {
              error: { id: 'InsufficientResources', message: 'Insufficient resources' }
            }
          end

          it 'marks the app as failed to stage' do
            expect {
              handler.staging_complete(staging_guid, payload)
            }.to change {
              app.reload.package_state
            }.from('PENDING').to('FAILED')
          end

          it 'records the error' do
            handler.staging_complete(staging_guid, payload)
            expect(app.reload.staging_failed_reason).to eq('InsufficientResources')
          end

          it 'logs an error for the CF user' do
            handler.staging_complete(staging_guid, payload)

            expect(Loggregator).to have_received(:emit_error).with(app.guid, /Insufficient resources/)
          end

          it 'returns without sending a desired request for the app' do
            handler.staging_complete(staging_guid, payload)

            expect(runners).not_to have_received(:runner_for_app)
            expect(runner).not_to have_received(:start)
          end
        end
      end
    end
  end
end
