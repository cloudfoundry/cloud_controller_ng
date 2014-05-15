require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DiegoClient do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:app) do
      app = AppFactory.make
      app.environment_json = {APP_KEY: "APP_VAL"}
      app
    end

    let(:blobstore_url_generator) do
      double("blobstore_url_generator",
             :droplet_download_url => "app_uri",
             :buildpack_cache_download_url => "http://buildpack-artifacts-cache.com",
             :app_package_download_url => "http://app-package.com"
      )
    end

    subject(:client) { DiegoClient.new(message_bus, blobstore_url_generator) }

    describe "desiring an app" do
      before do
        app.add_new_droplet("lol")
        app.current_droplet.update_staging_complete("./some-detected-command")
      end

      it "sends a nats message with the appropriate subject and payload" do
        client.send_desire_request(app)

        expected_message = {
            app_id: app.guid,
            app_version: app.version,
            memory_mb: app.memory,
            disk_mb: app.disk_quota,
            file_descriptors: app.file_descriptors,
            droplet_uri: "app_uri",
            stack: app.stack.name,
            start_command: "./some-detected-command",
            environment: client.environment(app)
        }

        expect(message_bus.published_messages).to have(1).messages
        nats_message = message_bus.published_messages.first
        expect(nats_message[:subject]).to eq("diego.desire.app")
        expect(nats_message[:message]).to eq(expected_message)
      end

      context "with a custom start command" do
        before { app.command = "/a/custom/command"; app.save }

        it "sends a message with the custom start command" do
          client.send_desire_request(app)

          expected_message = {
              app_id: app.guid,
              app_version: app.version,
              memory_mb: app.memory,
              disk_mb: app.disk_quota,
              file_descriptors: app.file_descriptors,
              droplet_uri: "app_uri",
              stack: app.stack.name,
              start_command: "/a/custom/command",
              environment: client.environment(app)
          }

          expect(message_bus.published_messages).to have(1).messages
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq("diego.desire.app")
          expect(nats_message[:message]).to eq(expected_message)
        end
      end
    end

    describe "staging an app" do
      it "sends a nats message with the appropriate staging subject and payload" do
        staging_task_id = "bogus id"
        client.send_stage_request(app, staging_task_id)

        expected_message = {
            :app_id => app.guid,
            :task_id => staging_task_id,
            :memory_mb => app.memory,
            :disk_mb => app.disk_quota,
            :file_descriptors => app.file_descriptors,
            :environment => client.environment(app),
            :stack => app.stack.name,
            :build_artifacts_cache_download_uri => "http://buildpack-artifacts-cache.com",
            :app_bits_download_uri => "http://app-package.com",
            :buildpacks => DiegoBuildpackEntryGenerator.new(blobstore_url_generator).buildpack_entries(app)
        }

        expect(message_bus.published_messages).to have(1).messages
        nats_message = message_bus.published_messages.first
        expect(nats_message[:subject]).to eq("diego.staging.start")
        expect(nats_message[:message]).to eq(expected_message)
      end
    end

    describe "#environment" do
      it "should return the correct environment hash for an application" do
        expected_environment = [
            {key: "VCAP_APPLICATION", value: app.vcap_application.to_json},
            {key: "VCAP_SERVICES", value: app.system_env_json["VCAP_SERVICES"].to_json},
            {key: "MEMORY_LIMIT", value: "#{app.memory}m"},
            {key: "APP_KEY", value: "APP_VAL"},
        ]
        expect(client.environment(app)).to eq(expected_environment)
      end
    end
  end

  describe VCAP::CloudController::DiegoBuildpackEntryGenerator do
    subject(:buildpack_entry_generator) { DiegoBuildpackEntryGenerator.new(blobstore_url_generator) }
    let(:app) { AppFactory.make(command: "/a/custom/command") }

    let(:admin_buildpack_download_url) { "http://admin-buildpack.com" }
    let(:app_package_download_url) { "http://app-package.com" }
    let(:build_artifacts_cache_download_uri) { "http://buildpack-artifacts-cache.com" }

    let(:blobstore_url_generator) { double("fake url generator") }

    before do
      Buildpack.create(name: "java", key: "java-buildpack-guid", position: 1)
      Buildpack.create(name: "ruby", key: "ruby-buildpack-guid", position: 2)

      allow(blobstore_url_generator).to receive(:app_package_download_url).and_return(app_package_download_url)
      allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return(admin_buildpack_download_url)
      allow(blobstore_url_generator).to receive(:buildpack_cache_download_url).and_return(build_artifacts_cache_download_uri)

      EM.stub(:add_timer)
      EM.stub(:defer).and_yield
    end

    describe "#buildpack_entries" do
      context "when the app has a GitBasedBuildpack" do
        context "when the GitBasedBuildpack uri begins with http(s)://" do
          before do
            app.buildpack = "http://github.com/mybuildpack/bp.zip"
          end

          it "should use the GitBasedBuildpack's uri and name it 'custom', and use the url as the key" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                               {name: "custom", key: "http://github.com/mybuildpack/bp.zip", url: "http://github.com/mybuildpack/bp.zip"}
                                                                           ])
          end
        end

        context "when the GitBasedBuildpack uri begins with git://" do
          before do
            app.buildpack = "git://github.com/mybuildpack/bp"
          end

          it "should use the list of admin buildpacks" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                               {name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url},
                                                                               {name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url},
                                                                           ])
          end
        end

        context "when the GitBasedBuildpack uri ends with .git" do
          before do
            app.buildpack = "https://github.com/mybuildpack/bp.git"
          end

          it "should use the list of admin buildpacks" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                               {name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url},
                                                                               {name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url},
                                                                           ])
          end
        end
      end

      context "when the app has a named buildpack" do
        before do
          app.buildpack = "java"
        end

        it "should use that buildpack" do
          expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                             {name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url},
                                                                         ])
        end
      end

      context "when the app has no buildpack specified" do
        it "should use the list of admin buildpacks" do
          expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                             {name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url},
                                                                             {name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url},
                                                                         ])
        end
      end
    end
  end
end