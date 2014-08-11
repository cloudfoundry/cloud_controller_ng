require "spec_helper"
require "cloud_controller/diego/docker/protocol"

module VCAP::CloudController
  module Diego
    module Docker
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

            it "includes a subject and message for CfMessageBus::MessageBus#publish" do
              expect(request.size).to eq(2)
              expect(request.first).to eq("diego.docker.staging.start")
              expect(request.last).to match_json(protocol.stage_app_message(app))
            end
          end

          describe "#stage_app_message" do
            subject(:message) do
              protocol.stage_app_message(app)
            end

            it "includes the fields needed to stage a Docker app" do
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

          describe "#desire_app_request" do
            subject(:request) do
              protocol.desire_app_request(app)
            end

            it "includes a subject and message for CfMessageBus::MessageBus#publish" do
              expect(request.size).to eq(2)
              expect(request.first).to eq("diego.docker.desire.app")
              expect(request.last).to match_json(protocol.desire_app_message(app))
            end
          end

          describe "#desire_app_message" do
            subject(:message) do
              protocol.desire_app_message(app)
            end

            it "includes the fields needed to desire a Docker app" do
              expect(message).to eq({
                "process_guid" => app.versioned_guid,
                "memory_mb" => app.memory,
                "disk_mb" => app.disk_quota,
                "file_descriptors" => app.file_descriptors,
                "stack" => app.stack.name,
                "start_command" => app.detected_start_command,
                "environment" => Environment.new(app).as_json,
                "num_instances" => app.desired_instances,
                "routes" => app.uris,
                "log_guid" => app.guid,
                "docker_image" => app.docker_image,
              })
            end

            context "when the app has a health_check_timeout" do
              before do
                app.health_check_timeout = 123
              end

              it "includes the timeout in the message" do
                expect(message["health_check_timeout_in_seconds"]).to eq(app.health_check_timeout)
              end
            end
          end
        end
      end
    end
  end
end
