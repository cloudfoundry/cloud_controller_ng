require "spec_helper"

module VCAP::CloudController
  module Diego
    describe Messenger do
      let(:enabled) { true }
      let(:message_bus) { CfMessageBus::MockMessageBus.new }

      let(:domain) { SharedDomain.make(name: "some-domain.com") }
      let(:route1) { Route.make(host: "some-route", domain: domain) }
      let(:route2) { Route.make(host: "some-other-route", domain: domain) }

      let(:app) do
        app = AppFactory.make
        app.instances = 3
        app.space.add_route(route1)
        app.space.add_route(route2)
        app.add_route(route1)
        app.add_route(route2)
        app.health_check_timeout = 120
        app
      end

      let(:blobstore_url_generator) do
        double("blobstore_url_generator",
          :perma_droplet_download_url => "app_uri",
          :buildpack_cache_download_url => "http://buildpack-artifacts-cache.com",
          :app_package_download_url => "http://app-package.com",
          :admin_buildpack_download_url => "https://example.com"
        )
      end

      let(:protocol) do
        Traditional::Protocol.new(blobstore_url_generator)
      end

      subject(:messenger) { Messenger.new(enabled, message_bus, protocol) }

      describe "staging an app" do
        it "sends a nats message with the appropriate staging subject and payload" do
          messenger.send_stage_request(app)

          expected_message = {
            "app_id" => app.guid,
            "task_id" => app.staging_task_id,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "environment" => Environment.new(app).as_json,
            "stack" => app.stack.name,
            "build_artifacts_cache_download_uri" => "http://buildpack-artifacts-cache.com",
            "app_bits_download_uri" => "http://app-package.com",
            "buildpacks" => Traditional::BuildpackEntryGenerator.new(blobstore_url_generator).buildpack_entries(app)
          }

          expect(message_bus.published_messages.size).to eq(1)
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq("diego.staging.start")
          expect(nats_message[:message]).to match_json(expected_message)
        end

        it "updates the app's staging task id so the staging response can be identified" do
          allow(VCAP).to receive(:secure_uuid).and_return("unique-staging-task-id")

          expect {
            messenger.send_stage_request(app)
          }.to change { app.refresh; app.staging_task_id }.to("unique-staging-task-id")
        end

        context "when the operator has disabled diego" do
          let(:enabled) { false }

          it "explodes with an API error that is propagated to cf users" do
            expect {
              messenger.send_stage_request(app)
            }.to raise_error(VCAP::Errors::ApiError, /Diego has not been enabled/)
          end
        end
      end

      describe "desiring an app" do
        let(:expected_message) do
          {
            "process_guid" => "#{app.guid}-#{app.version}",
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "droplet_uri" => "app_uri",
            "stack" => app.stack.name,
            "start_command" => "./some-detected-command",
            "environment" => Environment.new(app).as_json,
            "num_instances" => expected_instances,
            "routes" => ["some-route.some-domain.com", "some-other-route.some-domain.com"],
            "health_check_timeout_in_seconds" => 120,
            "log_guid" => app.guid,
          }
        end

        let(:expected_instances) { 3 }

        before do
          app.add_new_droplet("lol")
          app.current_droplet.update_start_command("./some-detected-command")
          app.state = "STARTED"
        end

        it "sends a nats message with the appropriate subject and payload" do
          messenger.send_desire_request(app)

          expect(message_bus.published_messages.size).to eq(1)
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq("diego.desire.app")
          expect(nats_message[:message]).to match_json(expected_message)
        end

        context "with a custom start command" do
          before { app.command = "/a/custom/command"; app.save }
          before { expected_message['start_command'] = "/a/custom/command" }

          it "sends a message with the custom start command" do
            messenger.send_desire_request(app)

            nats_message = message_bus.published_messages.first
            expect(nats_message[:subject]).to eq("diego.desire.app")
            expect(nats_message[:message]).to match_json(expected_message)
          end
        end

        context "when the app is not started" do
          let(:expected_instances) { 0 }

          before do
            app.state = "STOPPED"
          end

          it "should desire 0 instances" do
            messenger.send_desire_request(app)

            nats_message = message_bus.published_messages.first
            expect(nats_message[:subject]).to eq("diego.desire.app")
            expect(nats_message[:message]).to match_json(expected_message)
          end
        end

        context "when the operator has disabled diego" do
          let(:enabled) { false }

          it "explodes with an API error that is propagated to cf users" do
            expect {
              messenger.send_desire_request(app)
            }.to raise_error(VCAP::Errors::ApiError, /Diego has not been enabled/)
          end
        end
      end
    end
  end
end
