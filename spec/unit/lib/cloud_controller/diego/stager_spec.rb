require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe Stager do
      let(:messenger) { instance_double(Messenger, send_desire_request: nil) }
      let(:process) { AppFactory.make }
      let(:config) { TestConfig.config }

      subject(:stager) { Stager.new(process, config) }

      before do
        stager.messenger = messenger
      end

      it_behaves_like 'a stager'

      describe '#stage' do
        before do
          allow(messenger).to receive(:send_stage_request)
          allow(messenger).to receive(:send_stop_staging_request)
        end

        it 'notifies Diego that the process needs staging' do
          expect(process).to receive(:mark_for_restaging)
          expect(messenger).to receive(:send_stage_request).with(config)
          stager.stage
        end

        context 'when there is a pending stage' do
          context 'when a staging task id is nil' do
            before do
              process.staging_task_id = nil
            end

            it 'attempts to stop the outstanding stage request' do
              expect(messenger).to_not receive(:send_stop_staging_request)
              stager.stage
            end
          end

          context 'when a staging task id is not nil' do
            before do
              process.staging_task_id = Sham.guid
            end

            it 'attempts to stop the outstanding stage request' do
              expect(messenger).to receive(:send_stop_staging_request)
              stager.stage
            end
          end
        end

        context 'when the stage fails' do
          let(:error) do
            { error: { id: 'StagingError', message: 'Stager error: staging failed' } }
          end

          before do
            allow(messenger).to receive(:send_stage_request).and_raise(CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed'))
            allow(stager).to receive(:staging_complete)
          end

          it 'attempts to stop the outstanding stage request' do
            expect { stager.stage }.to raise_error(CloudController::Errors::ApiError)
            process.reload
            expect(stager).to have_received(:staging_complete).with(StagingGuid.from_process(process), error)
          end
        end
      end

      describe '#staging_complete' do
        let(:staging_guid) { 'a-staging-guid' }
        let(:staging_response) { { app_id: 'app-id' } }
        let(:buildpack_completion_handler) { instance_double(Diego::Buildpack::StagingCompletionHandler, staging_complete: nil) }
        let(:docker_completion_handler) { instance_double(Diego::Docker::StagingCompletionHandler, staging_complete: nil) }

        before do
          expect(process).to receive(:docker?).and_return(docker)
          allow(Diego::Buildpack::StagingCompletionHandler).to receive(:new).and_return(buildpack_completion_handler)
          allow(Diego::Docker::StagingCompletionHandler).to receive(:new).and_return(docker_completion_handler)
        end

        context 'docker' do
          let(:docker) { true }

          it 'delegates to the staging completion handler' do
            stager.staging_complete(staging_guid, staging_response)
            expect(docker_completion_handler).to have_received(:staging_complete).with(staging_guid, staging_response)
            expect(buildpack_completion_handler).not_to have_received(:staging_complete).with(staging_guid, staging_response)
          end
        end

        context 'buildpack' do
          let(:docker) { false }

          it 'delegates to the staging completion handler' do
            stager.staging_complete(staging_guid, staging_response)
            expect(docker_completion_handler).not_to have_received(:staging_complete).with(staging_guid, staging_response)
            expect(buildpack_completion_handler).to have_received(:staging_complete).with(staging_guid, staging_response)
          end
        end
      end

      describe '#stop_stage' do
        let(:process) { AppFactory.make(package_state: 'PENDING') }

        it 'tells diego to stop staging the application' do
          expect(messenger).to receive(:send_stop_staging_request)
          stager.stop_stage
        end
      end

      describe '#messenger' do
        it 'creates a Diego::Messenger if not set' do
          stager.messenger = nil
          expected_messenger = double
          allow(Diego::Messenger).to receive(:new).with(process).and_return(expected_messenger)
          expect(stager.messenger).to eq(expected_messenger)
        end
      end
    end
  end
end
