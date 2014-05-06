require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DiegoClient do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:app) { AppFactory.make(command: "/a/custom/command") }

    let(:blobstore_url_generator) do
      double("blobstore_url_generator", :droplet_download_url => "app_uri")
    end

    subject(:client) { DiegoClient.new(message_bus, blobstore_url_generator) }

    describe "desiring an app" do
      it "sends a nats message with the appropriate subject and payload" do
        client.desire(app)
        expected_message = {
            app_id: app.guid,
            app_version: app.version,
            droplet_uri: "app_uri",
            start_command: "/a/custom/command"
        }

        expect(message_bus.published_messages).to have(1).messages
        nats_message = message_bus.published_messages.first
        expect(nats_message[:subject]).to eq("diego.desire.app")
        expect(nats_message[:message]).to eq(expected_message)
      end
    end
  end
end
