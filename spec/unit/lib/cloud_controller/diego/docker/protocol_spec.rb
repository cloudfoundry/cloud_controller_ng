require "spec_helper"
require "cloud_controller/diego/docker/protocol"

module VCAP::CloudController
  module Diego::Docker
    describe Protocol do
      describe "#send_stage_request" do
        let(:app) do
          AppFactory.make(docker_image: "fake/docker_image")
        end

        subject(:protocol) do
          Protocol.new
        end

        describe "#stage_app_request" do
          subject(:request) do
            protocol.stage_app_request(app)
          end

          it "returns arguments intended for CfMessageBus::MessageBus#publish" do
            expect(request.size).to eq(2)
            expect(request.first).to eq("diego.docker.staging.start")
            expect(request.last).to match_json(protocol.stage_app_message(app))
          end
        end

        describe "#stage_app_message" do
          subject(:message) do
            protocol.stage_app_message(app)
          end

          it "uses the correct subject and the fields needed to stage an image" do
            expect(message).to eq({
              "app_id" => app.guid,
              "task_id" => app.staging_task_id,
              "memory_mb" => app.memory,
              "disk_mb" => app.disk_quota,
              "file_descriptors" => app.file_descriptors,
              "stack" => app.stack.name,
              "docker_image" => app.docker_image,
            })
          end
        end
      end
    end
  end
end
