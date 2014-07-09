require "spec_helper"

module VCAP::CloudController::Diego
  describe DiegoClient do
    let(:enabled) { true }
    let(:service_registry) { double(:service_registry) }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    let(:domain) { VCAP::CloudController::SharedDomain.make(name: "some-domain.com") }
    let(:route1) { VCAP::CloudController::Route.make(host: "some-route", domain: domain) }
    let(:route2) { VCAP::CloudController::Route.make(host: "some-other-route", domain: domain) }

    let(:app) do
      app = VCAP::CloudController::AppFactory.make
      app.instances = 3
      app.environment_json = {APP_KEY: "APP_VAL"}
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

    subject(:client) { DiegoClient.new(enabled, message_bus, service_registry, blobstore_url_generator) }

    describe '#connect!' do
      before do
        allow(service_registry).to receive(:run!)
      end

      it 'runs the service_registry' do
        client.connect!
        expect(service_registry).to have_received(:run!)
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
          "environment" => Yajl::Parser.parse(Yajl::Encoder.encode(client.environment(app))),
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
        client.send_desire_request(app)

        expect(message_bus.published_messages.size).to eq(1)
        nats_message = message_bus.published_messages.first
        expect(nats_message[:subject]).to eq("diego.desire.app")
        expect(nats_message[:message]).to match_json(expected_message)
      end

      context "with a custom start command" do
        before { app.command = "/a/custom/command"; app.save }
        before { expected_message['start_command'] = "/a/custom/command" }

        it "sends a message with the custom start command" do
          client.send_desire_request(app)

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
          client.send_desire_request(app)

          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq("diego.desire.app")
          expect(nats_message[:message]).to match_json(expected_message)
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
            :memory_mb => 2048,
            :disk_mb => 4096,
            :file_descriptors => app.file_descriptors,
            :environment => client.environment(app),
            :stack => app.stack.name,
            :build_artifacts_cache_download_uri => "http://buildpack-artifacts-cache.com",
            :app_bits_download_uri => "http://app-package.com",
            :buildpacks => BuildpackEntryGenerator.new(blobstore_url_generator).buildpack_entries(app)
        }

        expect(message_bus.published_messages.size).to eq(1)
        nats_message = message_bus.published_messages.first
        expect(nats_message[:subject]).to eq("diego.staging.start")
        expect(nats_message[:message]).to eq(expected_message)
      end
    end

    describe "#environment" do
      it "should return the correct environment hash for an application" do
        expected_environment = [
            {name: "VCAP_APPLICATION", value: app.vcap_application.to_json},
            {name: "VCAP_SERVICES", value: app.system_env_json["VCAP_SERVICES"].to_json},
            {name: "MEMORY_LIMIT", value: "#{app.memory}m"},
            {name: "APP_KEY", value: "APP_VAL"},
        ]

        expect(client.environment(app)).to match_object(expected_environment)
      end
    end

    describe "getting app instance information" do
      before do
        stub_request(:get, "http://some-tps-addr:5151/lrps/#{app.guid}-#{app.version}").to_return(
          status: 200,
          body: [{ process_guid: "abc", instance_guid: "123", index: 0, state: 'running', since_in_ns: '1257894000000000001' },
                 { process_guid: "abc", instance_guid: "456", index: 1, state: 'starting', since_in_ns: '1257895000000000001' },
                 { process_guid: "abc", instance_guid: "789", index: 1, state: 'crashed', since_in_ns: '1257896000000000001' }].to_json)

        allow(service_registry).to receive(:tps_addrs).and_return(['http://some-tps-addr:5151'])
      end

      it "reports each instance's index, state, since, process_guid, instance_guid" do
        expect(client.lrp_instances(app)).to eq([
          { process_guid: "abc", instance_guid: "123", index: 0, state: "RUNNING", since: 1257894000 },
          { process_guid: "abc", instance_guid: "456", index: 1, state: "STARTING", since: 1257895000 },
          { process_guid: "abc", instance_guid: "789", index: 1, state: "CRASHED", since: 1257896000 }
        ])
      end

      describe "timing out" do
        let(:http) { double(:http) }
        let(:expected_timeout) { 10 }

        before do
          allow(Net::HTTP).to receive(:new).and_return(http)
          allow(http).to receive(:get).and_return(double(:http_response, body: '{}'))
          allow(http).to receive(:read_timeout=)
          allow(http).to receive(:open_timeout=)
        end

        it "sets the read_timeout" do
          client.lrp_instances(app)
          expect(http).to have_received(:read_timeout=).with(expected_timeout)
        end

        it "sets the open_timeout" do
          client.lrp_instances(app)
          expect(http).to have_received(:open_timeout=).with(expected_timeout)
        end
      end
    end
  end
end
