require 'spec_helper'
require 'cloud_controller/diego/docker/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe StagingCompletionHandler do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
        let(:app) { AppModel.make }
        let(:package) { PackageModel.make(app: app) }
        let!(:build) { BuildModel.make(app: app, package: package, state: BuildModel::STAGING_STATE) }
        let(:runners) { instance_double(Runners) }

        subject(:handler) { StagingCompletionHandler.new(build, runners) }

        before do
          allow(Steno).to receive(:logger).and_return(logger)
          allow(Loggregator).to receive(:emit_error)
          set_current_user_as_admin(user: User.make(guid: '1234'), email: 'joe@joe.com', user_name: 'briggs')
        end

        describe '#staging_complete' do
          context 'success' do
            let(:payload) do
              {
                result: {
                  execution_metadata: '"{\"cmd\":[\"start\"]}"',
                  process_types:      { web: 'start' },
                  lifecycle_type:     'docker',
                  lifecycle_metadata: {
                    docker_image: docker_image_name,
                  }
                }
              }
            end
            let(:docker_image_name) { '' }

            it 'marks the build as staged' do
              expect {
                handler.staging_complete(payload)
              }.to change {
                build.reload.staged?
              }.from(false).to(true)
            end

            it 'expires any old droplets' do
              expect_any_instance_of(BitsExpiration).to receive(:expire_droplets!)
              subject.staging_complete(payload)
            end

            context 'when staging result is returned' do
              before do
                payload[:result][:process_types] = {
                  web:      'start me',
                  worker:   'hello',
                  anything: 'hi hi hi'
                }

                payload[:result][:execution_metadata] = 'black-box-string'
              end

              it 'updates the droplet with the metadata' do
                handler.staging_complete(payload)

                droplet = build.reload.droplet
                data = {
                  'web'      => 'start me',
                  'worker'   => 'hello',
                  'anything' => 'hi hi hi'
                }

                expect(droplet.execution_metadata).to eq('black-box-string')
                expect(droplet.process_types).to eq(data)
              end

              context 'when process_types is empty' do
                before do
                  payload[:result][:process_types] = nil
                end

                it 'gracefully sets process_types to an empty hash, but mark the build as failed' do
                  handler.staging_complete(payload)
                  expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
                  expect(build.error_id).to match(/StagingError/)
                end

                it 'logs an error for the CF user' do
                  handler.staging_complete(payload)

                  expect(Loggregator).to have_received(:emit_error).with(build.guid, /No process types returned from stager/)
                end
              end

              context 'when the build is already in a completed state' do
                before do
                  build.update(state: BuildModel::FAILED_STATE)
                end

                it 'does not update the build' do
                  expect {
                    subject.staging_complete(payload)
                  }.to raise_error(CloudController::Errors::ApiError)

                  expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
                end
              end
            end

            context 'when updating the droplet table fails' do
              let(:save_error) { StandardError.new('save-error') }
              let!(:droplet) { DropletModel.make(app: app, package: package, build: build) }

              before do
                allow_any_instance_of(DropletModel).to receive(:save_changes).and_raise(save_error)
              end

              it 'logs an error for the CF operator' do
                handler.staging_complete(payload)

                expect(logger).to have_received(:error).with(
                  'diego.staging.docker.saving-staging-result-failed',
                  staging_guid: build.guid,
                  response:     payload,
                  error:        'save-error',
                )
              end
            end

            context 'when a start is requested' do
              let(:runner) { instance_double(Diego::Runner, start: nil) }
              let!(:web_process) { ProcessModel.make(app: app, type: 'web') }

              before do
                allow(runners).to receive(:runner_for_app).and_return(runner)
              end

              it 'assigns the current droplet' do
                handler.staging_complete(payload, true)
                expect(app.reload.droplet).to eq(build.reload.droplet)
              end

              it 'runs the wep process of the app' do
                handler.staging_complete(payload, true)

                expect(runners).to have_received(:runner_for_app).with(web_process)
                expect(runner).to have_received(:start)
              end

              it 'records a buildpack set event for all processes' do
                ProcessModel.make(app: app, type: 'other')
                expect {
                  subject.staging_complete(payload, true)
                }.to change { AppUsageEvent.where(state: 'BUILDPACK_SET').count }.to(2).from(0)
              end

              context 'when this is not the most recent staging result' do
                before do
                  DropletModel.make(app: app, package: package, created_at: Time.now + 1.year)
                end

                it 'does not assign the current droplet' do
                  expect {
                    handler.staging_complete(payload, true)
                  }.not_to change { app.reload.droplet }.from(nil)
                end

                it 'does not start the app' do
                  handler.staging_complete(payload, true)
                  expect(runner).not_to have_received(:start)
                end
              end
            end

            context 'when a docker_image is returned' do
              let(:docker_image_name) { 'cached-docker-image' }

              it 'records it on the droplet' do
                handler.staging_complete(payload)
                build.reload
                expect(build.droplet).to_not be_nil
                expect(build.droplet.docker_receipt_image).to eq('cached-docker-image')
              end
            end
          end

          context 'failure' do
            let(:payload) do
              {
                error: { id: 'InsufficientResources', message: 'Insufficient resources' }
              }
            end

            context 'when the staging fails' do
              it 'should mark the build as failed' do
                handler.staging_complete(payload)
                expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
              end

              it 'should not create a droplet' do
                handler.staging_complete(payload)
                expect(build.reload.droplet).to be_nil
              end

              it 'records the error' do
                handler.staging_complete(payload)
                expect(build.reload.error_id).to eq('InsufficientResources')
                expect(build.reload.error_description).to eq('Insufficient resources')
              end

              it 'should emit a loggregator error' do
                expect(Loggregator).to receive(:emit_error).with(build.guid, /Insufficient resources/)
                handler.staging_complete(payload)
              end
            end

            context 'with a malformed success message' do
              let(:payload) do
                {
                  result: {
                    process_types:      { web: 'start' },
                    lifecycle_type:     'docker',
                    lifecycle_metadata: {
                      docker_image: 'docker_image_name'
                    }
                  }
                }
              end

              before do
                expect {
                  handler.staging_complete(payload)
                }.to raise_error(CloudController::Errors::ApiError)
              end

              it 'logs an error for the CF operator' do
                expect(logger).to have_received(:error).with(
                  'diego.staging.docker.success.invalid-message',
                  staging_guid: build.guid,
                  payload:      payload,
                  error:        '{ result => { execution_metadata => Missing key } }'
                )
              end

              it 'logs an error for the CF user' do
                expect(Loggregator).to have_received(:emit_error).with(build.guid, /Malformed message from Diego stager/)
              end

              it 'should mark the build as failed' do
                expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
              end
            end

            context 'with a malformed error message' do
              let(:payload) do
                {
                  error: { id: 'InsufficientResources' }
                }
              end

              it 'should mark the build as failed' do
                expect {
                  handler.staging_complete(payload)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
                expect(build.error_id).to match(/StagingError/)
              end

              it 'logs an error for the CF user' do
                expect {
                  handler.staging_complete(payload)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(Loggregator).to have_received(:emit_error).with(build.guid, /Malformed message from Diego stager/)
              end

              it 'logs an error for the CF operator' do
                expect {
                  handler.staging_complete(payload)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(logger).to have_received(:error).with(
                  'diego.staging.docker.failure.invalid-message',
                  staging_guid: build.guid,
                  payload:      payload,
                  error:        '{ error => { message => Missing key } }'
                )
              end
            end

            context 'when updating the build record with data from staging fails' do
              let(:payload) do
                {
                  error: { id: 'InsufficientResources', message: 'some message' }
                }
              end
              let(:save_error) { StandardError.new('save-error') }

              before do
                allow_any_instance_of(BuildModel).to receive(:save_changes).and_raise(save_error)
              end

              it 'logs an error for the CF operator' do
                handler.staging_complete(payload)

                expect(logger).to have_received(:error).with(
                  'diego.staging.docker.saving-staging-result-failed',
                  staging_guid: build.guid,
                  response:     payload,
                  error:        'save-error',
                )
              end
            end

            context 'when a start is requested' do
              let!(:web_process) { ProcessModel.make(app: app, type: 'web', state: 'STARTED') }

              it 'stops the web process of the app' do
                expect {
                  subject.staging_complete(payload, true)
                }.to change { web_process.reload.state }.to('STOPPED')
              end

              context 'when there is no web process for the app' do
                let(:web_process) { nil }

                it 'still marks the build as failed' do
                  subject.staging_complete(payload, true)
                  expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
                end
              end
            end
          end
        end
      end
    end
  end
end
