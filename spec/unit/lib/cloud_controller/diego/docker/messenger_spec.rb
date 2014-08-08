require "spec_helper"
require "cloud_controller/diego/docker/messenger"

module VCAP::CloudController
  module Diego::Docker
    describe Messenger do
      describe "#send_stage_request" do
        let(:message_bus) do
          instance_double(CfMessageBus::MessageBus, publish: nil)
        end

        let(:app) do
          VCAP::CloudController::AppFactory.make(docker_image: "fake/docker_image")
        end

        subject(:messenger) do
          Messenger.new(message_bus)
        end

        it "uses the correct subject and the fields needed to stage an image" do
          messenger.send_stage_request(app)

          expected_message = {
            "app_id" => app.guid,
            "task_id" => app.staging_task_id,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "stack" => app.stack.name,
            "docker_image" => app.docker_image,
          }

          expect(message_bus).to have_received(:publish).with("diego.docker.staging.start", expected_message)
        end

        it "sets the apps staging task id so its response is identified" do
          allow(VCAP).to receive(:secure_uuid).and_return("unique-staging-task-id")

          expect {
            messenger.send_stage_request(app)
          }.to change { app.refresh; app.staging_task_id }.to("unique-staging-task-id")
        end
      end
    end
  end
end
