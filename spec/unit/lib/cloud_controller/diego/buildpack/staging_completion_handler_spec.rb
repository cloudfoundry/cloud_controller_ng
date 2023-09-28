require 'spec_helper'
require 'cloud_controller/diego/buildpack/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe StagingCompletionHandler do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
        let(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'lifecycle-bp') }

        let(:buildpack1_name) { 'the-pleasant-buildpack' }
        let(:buildpack1_other_name) { 'valley' }
        let(:buildpack1_version) { '3.1' }
        let(:buildpack1_key) { 'vicuna' }
        let!(:buildpack1) { VCAP::CloudController::Buildpack.make(key: buildpack1_key, name: buildpack1_name, sha256_checksum: 'mammoth') }
        let(:buildpack2_name) { 'my-brilliant-buildpack' }
        let(:buildpack2_other_name) { 'launderette' }
        let(:buildpack2_version) { '95' }
        let(:buildpack2_key) { 'guanaco' }
        let!(:buildpack2) { VCAP::CloudController::Buildpack.make(key: buildpack2_key, name: buildpack2_name, sha256_checksum: 'languid') }
        let(:buildpack3_key) { 'git://my-buildpacks.tv/kate/allie.git' }
        let(:buildpack3_other_name) { 'hilltop' }
        let(:buildpack3_version) { 'ME' }

        let(:lifecycle_buildpacks) do
          [
            {
              name: buildpack1_other_name,
              version: buildpack1_version,
              key: buildpack1_key
            },
            {
              name: buildpack2_other_name,
              version: buildpack2_version,
              key: buildpack2_key
            },
            {
              name: buildpack3_other_name,
              version: buildpack3_version,
              key: buildpack3_key
            }
          ]
        end
        let(:success_response) do
          {
            result: {
              lifecycle_type: 'buildpack',
              lifecycle_metadata: {
                buildpack_key: buildpack.key,
                detected_buildpack: 'INTERCAL'
              },
              execution_metadata: '',
              process_types: {
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

        subject { StagingCompletionHandler.new(build, runners) }

        describe '#staging_complete' do
          let(:app) { AppModel.make }
          let(:package) { PackageModel.make(app:) }
          let!(:build) do
            BuildModel.make(app: app, package: package, state: BuildModel::STAGING_STATE).tap do |build|
              BuildpackLifecycleDataModel.make(build:)
            end
          end
          let(:staging_guid) { build.guid }

          before do
            allow(Steno).to receive(:logger).with('cc.stager').and_return(logger)
            allow(Steno).to receive(:logger).with('cc.action.sidecar_create').and_return(logger)
            allow(VCAP::AppLogEmitter).to receive(:emit_error)
          end

          describe 'success case' do
            let(:droplet) { DropletModel.make(app: app, package: package, state: DropletModel::STAGING_STATE) }

            before do
              build.update(droplet:)
            end

            it 'marks the droplet as staged' do
              expect do
                subject.staging_complete(success_response)
              end.to change { droplet.reload.staged? }.to(true)
            end

            it 'marks the build as staged' do
              expect do
                subject.staging_complete(success_response)
              end.to change { build.reload.staged? }.to(true)
            end

            context 'when the build does not have a droplet' do
              let(:droplet) { nil }

              it 'marks the build as failed' do
                subject.staging_complete(success_response)
                build.reload
                expect(build.state).to eq(BuildModel::FAILED_STATE)
                expect(build.error_id).to eq('StagingError')
                expect(build.error_description).to eq('Staging error: no droplet')
              end
            end

            context 'when staging result is returned' do
              before do
                success_response[:result][:process_types] = {
                  web: 'start me',
                  worker: 'hello',
                  anything: 'hi hi hi'
                }

                success_response[:result][:execution_metadata] = 'black-box-string'
              end

              it 'updates the droplet with the metadata' do
                subject.staging_complete(success_response)
                droplet.reload

                expect(droplet.execution_metadata).to eq('black-box-string')
                expect(droplet.process_types).to eq({
                                                      'web' => 'start me',
                                                      'worker' => 'hello',
                                                      'anything' => 'hi hi hi'
                                                    })
                expect(droplet.buildpack_receipt_buildpack).to eq('lifecycle-bp')
                expect(droplet.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
                expect(droplet.buildpack_receipt_detect_output).to eq('INTERCAL')
              end

              it 'expires any old droplets' do
                expect_any_instance_of(BitsExpiration).to receive(:expire_droplets!)
                subject.staging_complete(success_response)
              end

              context 'when there are sidecars in the staging result' do
                before do
                  success_response[:result][:sidecars] = [{
                    name: 'sleepy',
                    command: 'sleep infinity',
                    memory: 1000,
                    process_types: ['web']
                  }]
                end

                it 'saves the sidecars into the droplet' do
                  subject.staging_complete(success_response)
                  droplet.reload
                  expect(droplet.sidecars).to eq([{
                                                   'name' => 'sleepy',
                                                   'command' => 'sleep infinity',
                                                   'memory' => 1000,
                                                   'process_types' => ['web']
                                                 }])
                end
              end

              context 'when sidecars are NOT present in the staging result' do
                it 'does not set sidecars on the droplet' do
                  subject.staging_complete(success_response)

                  expect(droplet.sidecars).to be_nil
                end
              end

              context 'when sidecars is null in the staging result' do
                before do
                  success_response[:result][:sidecars] = nil
                end

                it 'does not set sidecars on the droplet' do
                  subject.staging_complete(success_response)

                  expect(droplet.sidecars).to be_nil
                end
              end

              context 'when process_types is empty' do
                before do
                  success_response[:result][:process_types] = nil
                end

                context 'and the app\'s web process does NOT have a start command' do
                  let(:runner) { instance_double(Diego::Runner, start: nil) }
                  let!(:web_process) { ProcessModel.make(app: app, type: 'web', state: 'STARTED', metadata: {}) }

                  before do
                    allow(runners).to receive(:runner_for_process).and_return(runner)
                  end

                  it 'gracefully sets process_types to an empty hash, and marks the droplet as failed' do
                    subject.staging_complete(success_response)
                    build.reload
                    expect(build.state).to eq(BuildModel::FAILED_STATE)
                    expect(build.error_id).to eq('StagingError')
                  end
                end

                context 'and the app\'s web process has a start command' do
                  let(:runner) { instance_double(Diego::Runner, start: nil) }
                  let!(:web_process) { ProcessModel.make(app: app, type: 'web', command: 'start me', state: 'STARTED', metadata: {}) }

                  before do
                    success_response[:result][:execution_metadata] = 'black-box-string'
                    allow(runners).to receive(:runner_for_process).and_return(runner)
                  end

                  it 'updates the droplet with the metadata' do
                    subject.staging_complete(success_response)
                    droplet.reload

                    expect(droplet.process_types).to eq({})
                    expect(droplet.execution_metadata).to eq('black-box-string')
                    expect(droplet.buildpack_receipt_buildpack).to eq('lifecycle-bp')
                    expect(droplet.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
                    expect(droplet.buildpack_receipt_detect_output).to eq('INTERCAL')
                  end
                end

                context 'when a start is requested' do
                  context 'and the app has a start command' do
                    let(:runner) { instance_double(Diego::Runner, start: nil) }
                    let!(:web_process) { ProcessModel.make(app: app, type: 'web', command: 'start me', state: 'STARTED', metadata: {}) }

                    before do
                      success_response[:result][:execution_metadata] = 'black-box-string'
                      allow(runners).to receive(:runner_for_process).and_return(runner)
                    end

                    context 'when revisions are enabled' do
                      let(:old_droplet) { DropletModel.make(app: app, created_at: 5.days.ago) }

                      before do
                        app.update(revisions_enabled: true)
                        RevisionModel.make(app_guid: app.guid, droplet_guid: old_droplet.guid)
                      end

                      it 'creates a revision and assigns it to the processes' do
                        expect { subject.staging_complete(success_response, true) }.to change { app.reload.revisions.count }.from(1).to(2)
                        web_process.reload
                        expect(web_process.revision).to eq(app.latest_revision)
                        expect(web_process.actual_droplet).to eq(app.droplet)
                      end
                    end

                    context 'when revisions are NOT enabled' do
                      before do
                        app.update(revisions_enabled: false)
                      end

                      it 'creates a revision and assigns it to the processes' do
                        expect { subject.staging_complete(success_response, true) }.not_to change { app.reload.revisions.count }.from(0)
                        web_process.reload
                        expect(web_process.revision).to be_nil
                        expect(web_process.actual_droplet).to eq(app.droplet)
                      end
                    end

                    context 'when there are sidecars on the droplet' do
                      before do
                        droplet.update(sidecars: [{
                                         'name' => 'sleepy',
                                         'command' => 'sleep infinity',
                                         'process_types' => ['web']
                                       }])
                      end

                      it 'materializes sidecars' do
                        expect(SidecarModel.count).to eq(0)

                        subject.staging_complete(success_response, true)

                        expect(SidecarModel.count).to eq(1)
                        sidecar = SidecarModel.last
                        expect(sidecar.name).to eq('sleepy')
                        expect(sidecar.command).to eq('sleep infinity')
                        expect(sidecar.process_types).to eq(['web'])
                        expect(sidecar.app_guid).to eq(app.guid)
                      end

                      context 'but the app has a user-origin sidecar of the same name' do
                        before do
                          SidecarModel.make(name: 'sleepy', command: 'sleep infinity', app: app, origin: SidecarModel::ORIGIN_USER)
                        end

                        it 'errors without materializing sidecars' do
                          expect do
                            subject.staging_complete(success_response, true)
                          end.not_to(change(SidecarModel, :count))

                          expect(build.state).to eq(BuildModel::FAILED_STATE)
                          expect(build.error_id).to eq('StagingError')
                          expect(build.error_description).to eq(
                            'Staging error: Buildpack defined sidecar \'sleepy\' conflicts with an ' \
                            'existing user-defined sidecar. Consider renaming \'sleepy\'.'
                          )
                        end
                      end
                    end
                  end

                  context 'when the app does not have a start command' do
                    let(:runner) { instance_double(Diego::Runner, start: nil) }
                    let!(:web_process) { ProcessModel.make(app: app, type: 'web', state: 'STARTED', metadata: {}) }

                    before do
                      allow(runners).to receive(:runner_for_process).and_return(runner)
                    end

                    it 'gracefully sets process_types to an empty hash, and marks the droplet as failed' do
                      subject.staging_complete(success_response, true)
                      build.reload
                      expect(build.state).to eq(BuildModel::FAILED_STATE)
                      expect(build.error_id).to eq('StagingError')
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

                it 'records the buildpack_lifecycle_buildpacks' do
                  success_response[:result][:lifecycle_metadata][:buildpacks] = lifecycle_buildpacks
                  subject.staging_complete(success_response)
                  expect(droplet.reload.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks.size).to eq(lifecycle_buildpacks.size)
                  expect(droplet.reload.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks).
                    to match_array(BuildpackLifecycleBuildpackModel.all)
                end

                context 'when lifecycle buildpacks do not have versions or names' do
                  let(:lifecycle_buildpacks) do
                    [{ key: buildpack1_key }, { key: buildpack2_key }, { key: buildpack3_key }]
                  end

                  it 'accepts the lifecycle buildpacks' do
                    success_response[:result][:lifecycle_metadata][:buildpacks] = lifecycle_buildpacks
                    subject.staging_complete(success_response)
                    expect(droplet.reload.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks.size).to eq(lifecycle_buildpacks.size)
                    expect(droplet.reload.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks).
                      to match_array(BuildpackLifecycleBuildpackModel.all)
                  end
                end
              end
            end

            context 'when updating the droplet record with data from staging fails' do
              let(:save_error) { StandardError.new('save-error') }
              let(:runner) { instance_double(Diego::Runner, start: nil) }
              let!(:web_process) { ProcessModel.make(app: app, type: 'web') }

              before do
                allow_any_instance_of(DropletModel).to receive(:save_changes).and_raise(save_error)
                allow(runners).to receive(:runner_for_process).and_return(runner)
              end

              it 'logs an error for the CF operator' do
                subject.staging_complete(success_response)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.saving-staging-result-failed',
                  hash_including(
                    staging_guid: build.guid,
                    response: success_response,
                    error: 'save-error'
                  )
                )
              end

              it 'does not attempt to start the app' do
                expect(runner).not_to receive(:start)
                expect(logger).not_to receive(:error).with(
                  'diego.staging.buildpack.starting-process-failed', anything
                )

                subject.staging_complete(success_response, true)
              end
            end

            context 'when a start is requested' do
              let(:runner) { instance_double(Diego::Runner, start: nil) }
              let!(:web_process) { ProcessModel.make(app: app, type: 'web') }

              before do
                allow(runners).to receive(:runner_for_process).and_return(runner)
              end

              it 'assigns the current droplet' do
                expect do
                  subject.staging_complete(success_response, true)
                end.to change { app.reload.droplet }.to(droplet)
              end

              it 'runs the wep process of the app' do
                subject.staging_complete(success_response, true)

                expect(runners).to have_received(:runner_for_process) do |process|
                  expect(process.guid).to eq(web_process.guid)
                end
                expect(runner).to have_received(:start)
              end

              it 'records a buildpack set event for all processes' do
                ProcessModel.make(app: app, type: 'other')
                expect do
                  subject.staging_complete(success_response, true)
                end.to change { AppUsageEvent.where(state: 'BUILDPACK_SET').count }.from(0).to(2)
              end

              it 'records a staging complete event for the build' do
                expect do
                  subject.staging_complete(success_response, true)
                end.to change { AppUsageEvent.where(state: 'STAGING_STOPPED').count }.from(0).to(1)
                event = AppUsageEvent.where(state: 'STAGING_STOPPED').last
                expect(event.buildpack_guid).to eq(buildpack.guid)
                expect(event.buildpack_name).to eq(buildpack.name)
              end

              context 'when this is not the most recent staging result' do
                before do
                  DropletModel.make(app:, package:)
                end

                it 'does not assign the current droplet' do
                  expect do
                    subject.staging_complete(success_response, true)
                  end.not_to change { app.reload.droplet }.from(nil)
                end

                it 'does not start the app' do
                  subject.staging_complete(success_response, true)
                  expect(runner).not_to have_received(:start)
                end
              end
            end

            context 'when a start is not requested' do
              let(:with_start) { false }
              let(:runner) { instance_double(Diego::Runner, start: nil) }
              let!(:web_process) { ProcessModel.make(app: app, type: 'web') }

              before do
                allow(runners).to receive(:runner_for_process).and_return(runner)
              end

              it 'records a staging complete event for the build' do
                expect do
                  subject.staging_complete(success_response, with_start)
                end.to change { AppUsageEvent.where(state: 'STAGING_STOPPED').count }.from(0).to(1)
                event = AppUsageEvent.where(state: 'STAGING_STOPPED').last
                expect(event.buildpack_guid).to eq(buildpack.guid)
                expect(event.buildpack_name).to eq(buildpack.name)
              end

              it 'records a buildpack set event for all processes' do
                ProcessModel.make(app: app, type: 'other')
                expect do
                  subject.staging_complete(success_response, with_start)
                end.to change { AppUsageEvent.where(state: 'BUILDPACK_SET').count }.from(0).to(1)
                event = AppUsageEvent.where(state: 'BUILDPACK_SET').last
                expect(event.buildpack_guid).to eq(buildpack.guid)
                expect(event.buildpack_name).to eq(buildpack.name)
                expect(event.parent_app_name).to eq(app.name)
                expect(event.parent_app_guid).to eq(app.guid)
              end

              it 'does not start the app' do
                subject.staging_complete(success_response, with_start)
                expect(runner).not_to have_received(:start)
              end
            end

            context 'when the build is already in a completed state' do
              before do
                build.update(state: BuildModel::FAILED_STATE)
              end

              it 'does not update the build' do
                expect do
                  subject.staging_complete(success_response)
                end.to raise_error(CloudController::Errors::ApiError)

                expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
              end
            end
          end

          describe 'failure case' do
            context 'when the staging fails' do
              it 'marks the build as failed' do
                subject.staging_complete(fail_response)
                build.reload

                expect(build.state).to eq(BuildModel::FAILED_STATE)
                expect(build.error_id).to eq('NoCompatibleCell')
                expect(build.error_description).to eq('Found no compatible cell')
              end

              it 'does not create a droplet' do
                subject.staging_complete(fail_response)
                expect(build.reload.droplet).to be_nil
              end

              it 'records the error' do
                subject.staging_complete(fail_response)

                build.reload
                expect(build.error_id).to eq('NoCompatibleCell')
                expect(build.error_description).to eq('Found no compatible cell')
              end

              it 'emits a loggregator error' do
                expect(VCAP::AppLogEmitter).to receive(:emit_error).with(build.app_guid, /Found no compatible cell/)
                subject.staging_complete(fail_response)
              end
            end

            context 'when the build does not have a droplet' do
              let(:droplet) { nil }

              it 'marks the build as failed' do
                subject.staging_complete(fail_response)
                build.reload
                expect(build.state).to eq(BuildModel::FAILED_STATE)
                expect(build.error_id).to eq('NoCompatibleCell')
                expect(build.error_description).to eq('Found no compatible cell')
              end
            end

            context 'with a malformed success message' do
              let(:droplet) { DropletModel.make(app: app, package: package, state: DropletModel::STAGING_STATE) }

              before do
                build.update(droplet:)
                expect do
                  subject.staging_complete(malformed_success_response)
                end.to raise_error(CloudController::Errors::ApiError)
              end

              it 'logs an error for the CF operator' do
                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.success.invalid-message',
                  staging_guid: build.guid,
                  payload: malformed_success_response,
                  error: '{ result => Missing key }'
                )
              end

              it 'logs an error for the CF user' do
                expect(VCAP::AppLogEmitter).to have_received(:emit_error).with(build.app_guid, /Malformed message from Diego stager/)
              end

              it 'marks the build as failed' do
                expect(build.reload.state).to eq(BuildModel::FAILED_STATE)
              end

              context 'with an unexpected format' do
                let(:malformed_success_response) do
                  { result: 'command' }
                end

                it 'logs a helpful error' do
                  expect(logger).to have_received(:error).with(
                    'diego.staging.buildpack.success.invalid-message',
                    staging_guid: build.guid,
                    payload: malformed_success_response,
                    error: '{ result => unexpected format }'
                  )
                end
              end
            end

            context 'with a malformed error message' do
              it 'marks the build as failed' do
                expect do
                  subject.staging_complete(malformed_fail_response)
                end.to raise_error(CloudController::Errors::ApiError)

                build.reload
                expect(build.state).to eq(BuildModel::FAILED_STATE)
                expect(build.error_id).to eq('StagingError')
              end

              it 'logs an error for the CF user' do
                expect do
                  subject.staging_complete(malformed_fail_response)
                end.to raise_error(CloudController::Errors::ApiError)

                expect(VCAP::AppLogEmitter).to have_received(:emit_error).with(build.app_guid, /Malformed message from Diego stager/)
              end

              it 'logs an error for the CF operator' do
                expect do
                  subject.staging_complete(malformed_fail_response)
                end.to raise_error(CloudController::Errors::ApiError)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.failure.invalid-message',
                  staging_guid: build.guid,
                  payload: malformed_fail_response,
                  error: '{ error => { message => Missing key } }'
                )
              end
            end

            context 'when updating the build record with data from staging fails' do
              let(:save_error) { StandardError.new('save-error') }

              before do
                allow_any_instance_of(BuildModel).to receive(:save_changes).and_raise(save_error)
              end

              it 'logs an error for the CF operator' do
                subject.staging_complete(fail_response)

                expect(logger).to have_received(:error).with(
                  'diego.staging.buildpack.saving-staging-result-failed',
                  hash_including(
                    staging_guid: build.guid,
                    response: fail_response,
                    error: 'save-error'
                  )
                )
              end
            end

            context 'when a start is requested' do
              let!(:web_process) { ProcessModel.make(app: app, type: 'web', state: 'STARTED') }

              it 'stops the web process of the app' do
                expect do
                  subject.staging_complete(fail_response, true)
                end.to change { web_process.reload.state }.to('STOPPED')
              end

              context 'when there is no web process for the app' do
                let(:web_process) { nil }

                it 'still marks the build as failed' do
                  subject.staging_complete(fail_response, true)
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
