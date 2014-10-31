require "spec_helper"

module VCAP::CloudController
  module Diego
    describe Stager do
      let(:messenger) do
        instance_double(Messenger, send_desire_request: nil)
      end

      let(:app) do
        instance_double(App)
      end

      let (:completion_handler) do
        instance_double(Diego::Traditional::StagingCompletionHandler, staging_complete: nil)
      end

      subject(:stager) do
        Stager.new(app, messenger, completion_handler)
      end

      describe "#stage" do
        before do
          allow(messenger).to receive(:send_stage_request)

          stager.stage
        end

        it "notifies Diego that the app needs staging" do
          expect(messenger).to have_received(:send_stage_request).with(app)
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
