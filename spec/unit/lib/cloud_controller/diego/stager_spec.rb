require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Stager do
      let(:messenger) { instance_double(Messenger, send_desire_request: nil) }
      let(:app) { AppFactory.make }
      let(:config) { TestConfig.config }

      let(:completion_handler) do
        instance_double(Diego::Buildpack::StagingCompletionHandler, staging_complete: nil)
      end

      subject(:stager) do
        Stager.new(app, messenger, completion_handler, config)
      end

      it_behaves_like 'a stager'

      describe '#stage' do
        before do
          allow(messenger).to receive(:send_stage_request)
          allow(messenger).to receive(:send_stop_staging_request)
        end

        it 'notifies Diego that the app needs staging' do
          expect(app).to receive(:mark_for_restaging)
          expect(messenger).to receive(:send_stage_request).with(app, config)
          stager.stage
        end

        context 'when there is a pending stage' do
          context 'when a staging task id is nil' do
            before do
              app.staging_task_id = nil
            end

            it 'attempts to stop the outstanding stage request' do
              expect(messenger).to_not receive(:send_stop_staging_request)
              stager.stage
            end
          end

          context 'when a staging task id is not nil' do
            before do
              app.staging_task_id = Sham.guid
            end

            it 'attempts to stop the outstanding stage request' do
              expect(messenger).to receive(:send_stop_staging_request).with(app)
              stager.stage
            end
          end
        end

        context 'when the stage fails' do
          let(:error) do
            { error: { id: 'StagingError', message: 'Stager error: staging failed' } }
          end

          before do
            allow(messenger).to receive(:send_stage_request).and_raise Errors::ApiError.new_from_details('StagerError', 'staging failed')
            allow(stager).to receive(:staging_complete)
          end

          it 'attempts to stop the outstanding stage request' do
            expect { stager.stage }.to raise_error(Errors::ApiError)
            app.reload
            expect(stager).to have_received(:staging_complete).with(StagingGuid.from_app(app), error)
          end
        end
      end

      describe '#staging_complete' do
        let(:staging_guid) { 'a-staging-guid' }
        let(:staging_response) { { app_id: 'app-id' } }

        before do
          allow(completion_handler).to receive(:staging_complete)

          stager.staging_complete(staging_guid, staging_response)
        end

        it 'delegates to the staging completion handler' do
          expect(completion_handler).to have_received(:staging_complete).with(staging_guid, staging_response)
        end
      end

      describe '#stop_stage' do
        let(:app) { AppFactory.make(package_state: 'PENDING') }

        it 'tells diego to stop staging the application' do
          expect(messenger).to receive(:send_stop_staging_request)
          stager.stop_stage
        end
      end
    end
  end
end
