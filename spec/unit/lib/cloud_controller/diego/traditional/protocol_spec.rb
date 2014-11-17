require "spec_helper"

module VCAP::CloudController
  module Diego
    module Traditional
      describe Protocol do
        let(:blobstore_url_generator) do
          instance_double(CloudController::Blobstore::UrlGenerator,
            :buildpack_cache_download_url => "http://buildpack-artifacts-cache.com",
            :app_package_download_url => "http://app-package.com",
            :perma_droplet_download_url => "fake-droplet_uri",
            :buildpack_cache_upload_url => "http://buildpack-artifacts-cache.up.com",
            :droplet_upload_url => "http://droplet-upload-uri",
          )
        end

        subject(:protocol) do
          Protocol.new(blobstore_url_generator)
        end

        describe "#stage_app_request" do
          let(:app) do
            AppFactory.make
          end

          subject(:request) do
            protocol.stage_app_request(app)
          end

          it "returns arguments intended for CfMessageBus::MessageBus#publish" do
            expect(request.size).to eq(2)
            expect(request.first).to eq("diego.staging.start")
            expect(request.last).to match_json(protocol.stage_app_message(app))
          end
        end

        describe "#stage_app_message" do
          let(:staging_app) { AppFactory.make }
          subject(:message) { protocol.stage_app_message(staging_app) }

          before do
            staging_app.update(staging_task_id: "fake-staging-task-id") # Mimic Diego::Messenger#send_stage_request
          end

          it "is a nats message with the appropriate staging subject and payload" do
            buildpack_entry_generator = BuildpackEntryGenerator.new(blobstore_url_generator)

            expect(message).to eq(
              "app_id" => staging_app.guid,
              "task_id" => "fake-staging-task-id",
              "memory_mb" => staging_app.memory,
              "disk_mb" => staging_app.disk_quota,
              "file_descriptors" => staging_app.file_descriptors,
              "environment" => Environment.new(staging_app).as_json,
              "stack" => staging_app.stack.name,
              "build_artifacts_cache_download_uri" => "http://buildpack-artifacts-cache.com",
              "build_artifacts_cache_upload_uri" => "http://buildpack-artifacts-cache.up.com",
              "app_bits_download_uri" => "http://app-package.com",
              "buildpacks" => buildpack_entry_generator.buildpack_entries(staging_app),
              "droplet_upload_uri" => "http://droplet-upload-uri",
            )
          end
        end

        describe "#desire_app_request" do
          let(:app) { AppFactory.make }
          subject(:request) { protocol.desire_app_request(app) }

          it "returns arguments intended for CfMessageBus::MessageBus#publish" do
            expect(request.size).to eq(2)
            expect(request.first).to eq("diego.desire.app")
            expect(request.last).to match_json(protocol.desire_app_message(app))
          end
        end

        describe "#desire_app_message" do
          let(:app) do
            instance_double(App,
              execution_metadata: "staging-metadata",
              desired_instances: 111,
              disk_quota: 222,
              file_descriptors: 333,
              guid: "fake-guid",
              command: "the-custom-command",
              health_check_timeout: 444,
              memory: 555,
              stack: instance_double(Stack, name: "fake-stack"),
              versioned_guid: "fake-versioned_guid",
              uris: ["fake-uris"],
            )
          end

          before do
            environment = instance_double(Environment, as_json: [{"name" => "fake", "value" => "environment"}])
            allow(Environment).to receive(:new).with(app).and_return(environment)
          end

          subject(:message) do
            protocol.desire_app_message(app)
          end

          it "is a messsage with the information nsync needs to desire the app" do
            expect(message).to eq(
              "disk_mb" => 222,
              "droplet_uri" => "fake-droplet_uri",
              "environment" => [{"name" => "fake", "value" => "environment"}],
              "file_descriptors" => 333,
              "health_check_timeout_in_seconds" => 444,
              "log_guid" => "fake-guid",
              "memory_mb" => 555,
              "num_instances" => 111,
              "process_guid" => "fake-versioned_guid",
              "stack" => "fake-stack",
              "start_command" => "the-custom-command",
              "execution_metadata" => "staging-metadata",
              "routes" => ["fake-uris"],
            )
          end

          context "when the app does not have a health_check_timeout set" do
            before do
              allow(app).to receive(:health_check_timeout).and_return(nil)
            end

            it "omits health_check_timeout_in_seconds" do
              expect(message).not_to have_key("health_check_timeout_in_seconds")
            end
          end
        end

        describe "#stop_staging_app_request" do
          let(:app) do
            AppFactory.make
          end
          let(:task_id) {'staging_task_id'}

          subject(:request) do
            protocol.stop_staging_app_request(app, task_id)
          end

          it "returns an array of arguments including the subject and message" do
            expect(request.size).to eq(2)
            expect(request[0]).to eq("diego.staging.stop")
            expect(request[1]).to match_json(protocol.stop_staging_message(app, task_id))
          end
        end

        describe "#stop_staging_message" do
          let(:staging_app) { AppFactory.make }
          let(:task_id) {'staging_task_id'}
          subject(:message) { protocol.stop_staging_message(staging_app, task_id) }

          it "is a nats message with the appropriate staging subject and payload" do
            expect(message).to eq(
              "app_id" => staging_app.guid,
              "task_id" => task_id,
            )
          end
        end
      end
    end
  end
end
