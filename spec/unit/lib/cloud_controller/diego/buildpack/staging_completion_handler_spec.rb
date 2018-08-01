require 'spec_helper'
require 'cloud_controller/diego/buildpack/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe StagingCompletionHandler do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
        let(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'lifecycle-bp') }
        let(:success_response) do
          {
            result: {
              lifecycle_type:     'buildpack',
              lifecycle_metadata: {
                buildpack_key:      buildpack.key,
                detected_buildpack: 'INTERCAL',
              },
              execution_metadata: '',
              process_types:      {
                web: 'some command'
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
          { error: { id: 'stuff' } }
        end
        let(:runners) { instance_double(Runners) }

        subject { StagingCompletionHandler.new(droplet, runners) }

        describe '#staging_complete' do
          let(:app) { AppModel.make }
          let(:package) { PackageModel.make(app: app) }
          let!(:droplet) { DropletModel.make(app: app, package: package, state: DropletModel::STAGING_STATE) }
          let(:staging_guid) { droplet.guid }

          before do
            allow(Steno).to receive(:logger).with('cc.stager').and_return(logger)
            allow(Loggregator).to receive(:emit_error)
          end

          describe 'success case' do
            it 'marks the droplet as staged' do
              expect {
                subject.staging_complete(success_response)
              }.to change { droplet.reload.staged? }.to(true)
            end

            context 'when staging result is returned' do
              before do
                success_response[:result][:process_types] = {
                  web:      'start me',
                  worker:   'hello',
                  anything: 'hi hi hi'
                }

                success_response[:result][:execution_metadata] = 'black-box-string'
              end

              it 'updates the droplet with the metadata' do
                subject.staging_complete(success_response)
                droplet.reload
                data = {
                  'web'      => 'start me',
                  'worker'   => 'hello',
                  'anything' => 'hi hi hi'
                }

                expect(droplet.execution_metadata).to eq('black-box-string')
                expect(droplet.process_types).to eq(data)
                expect(droplet.buildpack_receipt_buildpack).to eq('lifecycle-bp')
                expect(droplet.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
                expect(droplet.buildpack_receipt_detect_output).to eq('INTERCAL')
              end

              it 'expires any old droplets' do
                expect_any_instance_of(BitsExpiration).to receive(:expire_droplets!)
                subject.staging_complete(success_response)
              end

              context 'when process_types is empty' do
                before do
                  success_response[:result][:process_types] = nil
                end

                it 'gracefully sets process_types to an empty hash, but mark the droplet as failed' do
                  subject.staging_complete(success_response)
                  expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
                  expect(droplet.error).to match(/StagingError/)
                end

                context 'when a start is requested' do
                  context 'and the app has a start command' do
                    let(:runner) { instance_double(Diego::Runner, start: nil) }
                    let!(:web_process) { App.make(app: app, type: 'web', command: 'start me', state: 'STARTED', metadata: {}) }

                    before do
                      success_response[:result][:execution_metadata] = 'black-box-string'
                      allow(runners).to receive(:runner_for_app).and_return(runner)
                    end

                    it 'updates the droplet with the metadata' do
                      subject.staging_complete(success_response, true)
                      droplet.reload

                      expect(droplet.process_types).to eq({})
                      expect(droplet.execution_metadata).to eq('black-box-string')
                      expect(droplet.buildpack_receipt_buildpack).to eq('lifecycle-bp')
                      expect(droplet.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
                      expect(droplet.buildpack_receipt_detect_output).to eq('INTERCAL')
                    end
                  end

                  context 'when the app does not have a start command' do
                    let(:runner) { instance_double(Diego::Runner, start: nil) }
                    let!(:web_process) { App.make(app: app, type: 'web', state: 'STARTED', metadata: {}) }

                    before do
                      allow(runners).to receive(:runner_for_app).and_return(runner)
                    end

                    it 'gracefully sets process_types to an empty hash, and marks the droplet as failed' do
                      subject.staging_complete(success_response, true)
                      expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
                      expect(droplet.error).to match(/StagingError/)
                    end
                  end
                end
              end

              describe 'recording buildpack receipt' do
                it 'records detected_buildpack' do
                  success_response[:result][:lifecycle_metadata][:detected_buildpack] = 'detect output'
                  subject.staging_complete(success_response)

                  expect(droplet.reload.buildpack_receipt_detect_output).to eq('detect output')
                end

                context 'when the buildpack key is a url' do
                  it 'records that as the buildpack' do
                    success_response[:result][:lifecycle_metadata][:buildpack_key] = 'https://www.buildpack.com'
                    subject.staging_complete(success_response)

                    expect(droplet.reload.buildpack_receipt_buildpack).to eq('https://www.buildpack.com')
                  end
                end

                context 'when the buildpack key is a key' do
                  it 'records that as the buildpack' do
                    admin_buildpack = VCAP::CloudController::Buildpack.make(name: 'woop', key: 'thismakey')

                    success_response[:result][:lifecycle_metadata][:buildpack_key] = 'thismakey'
                    subject.staging_complete(success_response)

                    expect(droplet.reload.buildpack_receipt_buildpack).to eq('woop')
                    expect(droplet.reload.buildpack_receipt_buildpack_guid).to eq(admin_buildpack.guid)
                  end
                end
              end
            end

            context 'when updating the droplet record with data from staging fails' do
              let(:save_error) { StandardError.new('save-error') }

              before do
                allow_any_instance_of(DropletModel).to receive(:save_changes).and_raise(save_error)
              end

              it 'logs an error for the CF operator' do
                subject.staging_complete(success_response)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.saving-staging-result-failed',
                  staging_guid: droplet.guid,
                  response:     success_response,
                  error:        'save-error',
                )
              end
            end

            context 'when a start is requested' do
              let(:runner) { instance_double(Diego::Runner, start: nil) }
              let!(:web_process) { App.make(app: app, type: 'web') }

              before do
                allow(runners).to receive(:runner_for_app).and_return(runner)
              end

              it 'assigns the current droplet' do
                expect {
                  subject.staging_complete(success_response, true)
                }.to change { app.reload.droplet }.to(droplet)
              end

              it 'runs the wep process of the app' do
                subject.staging_complete(success_response, true)

                expect(runners).to have_received(:runner_for_app) do |process|
                  expect(process.guid).to eq(web_process.guid)
                end
                expect(runner).to have_received(:start)
              end

              it 'records a buildpack set event for all processes' do
                App.make(app: app, type: 'other')
                expect {
                  subject.staging_complete(success_response, true)
                }.to change { AppUsageEvent.where(state: 'BUILDPACK_SET').count }.to(2).from(0)
              end

              context 'when this is not the most recent staging result' do
                before do
                  DropletModel.make(app: app, package: package)
                end

                it 'does not assign the current droplet' do
                  expect {
                    subject.staging_complete(success_response, true)
                  }.not_to change { app.reload.droplet }.from(nil)
                end

                it 'does not start the app' do
                  subject.staging_complete(success_response, true)
                  expect(runner).not_to have_received(:start)
                end
              end
            end

            context 'when the droplet is already in a completed state' do
              before do
                droplet.update(state: DropletModel::FAILED_STATE)
              end

              it 'does not update the droplet' do
                expect {
                  subject.staging_complete(success_response)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
              end
            end
          end

          describe 'failure case' do
            context 'when the staging fails' do
              it 'should mark the droplet as failed' do
                subject.staging_complete(fail_response)
                expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
              end

              it 'records the error' do
                subject.staging_complete(fail_response)
                expect(droplet.reload.error).to eq('NoCompatibleCell - Found no compatible cell')
              end

              it 'should emit a loggregator error' do
                expect(Loggregator).to receive(:emit_error).with(droplet.guid, /Found no compatible cell/)
                subject.staging_complete(fail_response)
              end
            end

            context 'with a malformed success message' do
              before do
                expect {
                  subject.staging_complete(malformed_success_response)
                }.to raise_error(CloudController::Errors::ApiError)
              end

              it 'logs an error for the CF operator' do
                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.success.invalid-message',
                  staging_guid: droplet.guid,
                  payload:      malformed_success_response,
                  error:        '{ result => Missing key }'
                )
              end

              it 'logs an error for the CF user' do
                expect(Loggregator).to have_received(:emit_error).with(droplet.guid, /Malformed message from Diego stager/)
              end

              it 'should mark the droplet as failed' do
                expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
              end
            end

            context 'with a malformed error message' do
              it 'should mark the droplet as failed' do
                expect {
                  subject.staging_complete(malformed_fail_response)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
                expect(droplet.error).to match(/StagingError/)
              end

              it 'logs an error for the CF user' do
                expect {
                  subject.staging_complete(malformed_fail_response)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(Loggregator).to have_received(:emit_error).with(droplet.guid, /Malformed message from Diego stager/)
              end

              it 'logs an error for the CF operator' do
                expect {
                  subject.staging_complete(malformed_fail_response)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.failure.invalid-message',
                  staging_guid: droplet.guid,
                  payload:      malformed_fail_response,
                  error:        '{ error => { message => Missing key } }'
                )
              end
            end

            context 'when updating the droplet record with data from staging fails' do
              let(:save_error) { StandardError.new('save-error') }

              before do
                allow_any_instance_of(DropletModel).to receive(:save_changes).and_raise(save_error)
              end

              it 'logs an error for the CF operator' do
                subject.staging_complete(fail_response)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.saving-staging-result-failed',
                  staging_guid: droplet.guid,
                  response:     fail_response,
                  error:        'save-error',
                )
              end
            end

            context 'when a start is requested' do
              let!(:web_process) { App.make(app: app, type: 'web', state: 'STARTED') }

              it 'stops the web process of the app' do
                expect {
                  subject.staging_complete(fail_response, true)
                }.to change { web_process.reload.state }.to('STOPPED')
              end

              context 'when there is no web process for the app' do
                let(:web_process) { nil }

                it 'still marks the droplet as failed' do
                  subject.staging_complete(fail_response, true)
                  expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
                end
              end
            end
          end
        end
      end
    end
  end
end
