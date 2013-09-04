require "spec_helper"

module CloudController
  describe TaskClient do
    include RSpec::Mocks::ExampleMethods # for double

    before do
      @message_bus = VCAP::CloudController::Config.message_bus
      @task_client = TaskClient.new(@message_bus)

      @app = double(:app).as_null_object
      @task = VCAP::CloudController::Task.new(guid: "some guid", app: @app, secure_token: "42")
    end

    describe "#start_task" do
      it "sends task.start with the public key and the app's droplet URI" do
        VCAP::CloudController::StagingsController.stub(:droplet_download_uri).with(@app) do
          "https://some-download-uri"
        end

        @task_client.start_task(@task)

        expect(@message_bus).to have_published_with_message("task.start", {
            task: "some guid",
            secure_token: "42",
            package: "https://some-download-uri"
        })
      end
    end

    describe "#stop_task" do
      it "sends task.start with the public key and the app's droplet URI" do
        @task_client.stop_task(@task)

        expect(@message_bus).to have_published_with_message("task.stop", task: "some guid")
      end
    end
  end
end
