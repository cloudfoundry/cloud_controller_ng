require "spec_helper"

module CloudController
  describe TaskClient do
    include RSpec::Mocks::ExampleMethods # for double

    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    before { TaskClient.configure(message_bus) }

    describe "#start_task" do
      let(:app) { double :app }

      let(:task) do
        double :task, :guid => "some guid",
         :app => app, :secure_token => "42"
      end

      it "sends task.start with the public key and the app's droplet URI" do
        VCAP::CloudController::StagingsController.stub(
            :droplet_download_uri).with(app) do
          "https://some-download-uri"
        end

        message_bus.should_receive(:publish).with(
          "task.start",
          hash_including(
            :task => "some guid",
            :secure_token => "42",
            :package => "https://some-download-uri"))

        TaskClient.start_task(task)
      end
    end

    describe "#stop_task" do
      let(:app) { double :app }

      let(:task) do
        double :task, :guid => "some guid", :app => app
      end

      it "sends task.start with the public key and the app's droplet URI" do
        message_bus.should_receive(:publish).with(
          "task.stop",
          hash_including(:task => task.guid))

        TaskClient.stop_task(task)
      end
    end
  end
end