require 'spec_helper'
require 'cloud_controller/diego/traditional/v3/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        describe StagingCompletionHandler do
          let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
          let(:buildpack) { Buildpack.make }
          let(:success_response) do
            {
              execution_metadata: '{"process_types": { "web": "some command"}}',
              lifecycle_data:         {
                buildpack_key:      buildpack.key,
                detected_buildpack: 'INTERCAL',
              }
            }
          end
          let(:malformed_success_response) do
            success_response.except(:execution_metadata)
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

          subject { StagingCompletionHandler.new(runners) }

          describe '#staging_complete' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:staged_droplet) { DropletModel.make(app_guid: app.guid, package_guid: package.guid, state: 'PENDING') }
            let(:staging_guid) { staged_droplet.guid }

            def handle_staging_result(response)
              subject.staging_complete(staged_droplet, response)
            end

            before do
              allow(Steno).to receive(:logger).with('cc.stager').and_return(logger)
            end

            describe 'success case' do
              it 'marks the droplet as staged' do
                expect {
                  handle_staging_result(success_response)
                }.to change { staged_droplet.reload.staged? }.to(true)
              end

              context 'when staging metadata is returned' do
                before do
                  metadata = {
                      process_types: {
                          web: 'start me',
                          worker: 'hello',
                          anything: 'hi hi hi'
                      }
                  }
                  success_response[:execution_metadata] = MultiJson.dump(metadata)
                end

                it 'updates the droplet with the metadata' do
                  handle_staging_result(success_response)
                  staged_droplet.reload
                  droplet = staged_droplet
                  expect(droplet.procfile).to eq("web: start me\nworker: hello\nanything: hi hi hi")
                  expect(droplet.buildpack).to eq('INTERCAL')
                end

                context 'when detected_buildpack is empty' do
                  before do
                    staged_droplet.buildpack = 'OG BP'
                    staged_droplet.save

                    success_response[:lifecycle_data][:detected_buildpack] = ''
                  end

                  it 'does NOT override existing buildpack value' do
                    handle_staging_result(success_response)
                    expect(staged_droplet.reload.buildpack).to eq('OG BP')
                  end
                end
              end
            end

            describe 'failure case' do
              context 'when the staging fails' do
                it 'should mark the droplet as failed' do
                  handle_staging_result(fail_response)
                  expect(staged_droplet.reload.state).to eq(DropletModel::FAILED_STATE)
                end

                it 'records the error' do
                  handle_staging_result(fail_response)
                  expect(staged_droplet.reload.error).to eq('NoCompatibleCell - Found no compatible cell')
                end

                it 'should emit a loggregator error' do
                  expect(Loggregator).to receive(:emit_error).with(staged_droplet.guid, /Found no compatible cell/)
                  handle_staging_result(fail_response)
                end
              end

              context 'with a malformed success message' do
                before do
                  expect {
                    handle_staging_result(malformed_success_response)
                  }.to raise_error(VCAP::Errors::ApiError)
                end

                it 'logs an error for the CF operator' do
                  expect(logger).to have_received(:error).with(
                      'diego.staging.success.invalid-message',
                      staging_guid: staged_droplet.guid,
                      payload:      malformed_success_response,
                      error:        '{ execution_metadata => Missing key }'
                    )
                end
              end

              context 'with a malformed error message' do
                it 'should not emit any loggregator messages' do
                  expect(Loggregator).not_to receive(:emit_error).with(staged_droplet.guid, /bad/)
                  handle_staging_result(malformed_fail_response)
                end
              end

              context 'when updating the droplet record with data from staging fails' do
                let(:save_error) { StandardError.new('save-error') }

                before do
                  allow_any_instance_of(DropletModel).to receive(:save_changes).and_raise(save_error)
                end

                it 'logs an error for the CF operator' do
                  handle_staging_result(success_response)

                  expect(logger).to have_received(:error).with(
                      'diego.staging.v3.saving-staging-result-failed',
                      staging_guid: staged_droplet.guid,
                      response:     success_response,
                      error:        'save-error',
                    )
                end
              end
            end
          end
        end
      end
    end
  end
end
