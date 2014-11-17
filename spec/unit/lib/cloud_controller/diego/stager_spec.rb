require "spec_helper"

module VCAP::CloudController
  module Diego
    describe Stager do
      let(:messenger) do
        instance_double(Messenger, send_desire_request: nil)
      end

      let(:app) { AppFactory.make(staging_task_id: 'first_id') }

      let (:completion_handler) do
        instance_double(Diego::Traditional::StagingCompletionHandler, staging_complete: nil)
      end

      subject(:stager) do
        Stager.new(app, messenger, completion_handler)
      end

      describe "#stage" do
        let(:task_id) {app.staging_task_id}

        before do
          allow(messenger).to receive(:send_stage_request)
          allow(messenger).to receive(:send_stop_staging_request)
        end

        it "notifies Diego that the app needs staging" do
          expect(messenger).to receive(:send_stage_request)
          stager.stage
        end

        context "when there is a pending stage" do
          it "attempts to stop the outstanding stage request" do
            expect(messenger).to receive(:send_stop_staging_request).with(app, task_id)
            stager.stage
          end
        end
      end

      describe "#staging_complete" do
        let (:staging_response) do
          { app_id: "app-id", task_id: "task_id" }
        end

        before do
          allow(completion_handler).to receive(:staging_complete)

          stager.staging_complete(staging_response)
        end

        it "delegates to the staging completion handler" do
          expect(completion_handler).to have_received(:staging_complete).with(staging_response)
        end
      end
    end
  end
end
