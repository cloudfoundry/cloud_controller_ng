require "spec_helper"

module VCAP::CloudController::Diego
  describe Client do
    let(:service_registry) { double(:service_registry) }
    let(:app) { VCAP::CloudController::AppFactory.make }
    subject(:client) { Client.new(service_registry) }

    describe "#connect!" do
      before do
        allow(service_registry).to receive(:run!)
      end

      it "runs the service_registry" do
        client.connect!
        expect(service_registry).to have_received(:run!)
      end
    end

    describe "getting app instance information" do
      context "when there are tps addresses registered" do
        before do
          allow(service_registry).to receive(:tps_addrs).and_return(["http://some-tps-addr:5151"])
        end

        context "and the first endpoint returns instance info" do
          before do
            stub_request(:get, "http://some-tps-addr:5151/lrps/#{app.guid}-#{app.version}").to_return(
              status: 200,
              body: [{process_guid: "abc", instance_guid: "123", index: 0, state: "running", since_in_ns: "1257894000000000001"},
                {process_guid: "abc", instance_guid: "456", index: 1, state: "starting", since_in_ns: "1257895000000000001"},
                {process_guid: "abc", instance_guid: "789", index: 1, state: "crashed", since_in_ns: "1257896000000000001"}].to_json)

            allow(service_registry).to receive(:tps_addrs).and_return(["http://some-tps-addr:5151"])
          end

          it "reports each instance's index, state, since, process_guid, instance_guid" do
            expect(client.lrp_instances(app)).to eq([
              {process_guid: "abc", instance_guid: "123", index: 0, state: "RUNNING", since: 1257894000},
              {process_guid: "abc", instance_guid: "456", index: 1, state: "STARTING", since: 1257895000},
              {process_guid: "abc", instance_guid: "789", index: 1, state: "CRASHED", since: 1257896000}
            ])
          end
        end

        context "when the TPS endpoint is unavailable" do
          before do
            stub_request(:get, "http://some-tps-addr:5151/lrps/#{app.guid}-#{app.version}").to_raise(Errno::ECONNREFUSED)
          end

          it "raises Diego::Unavailable" do
            expect { client.lrp_instances(app) }.to raise_error(Unavailable, /connection refused/i)
          end
        end

        context "when the TPS endpoint fails" do
          before do
            stub_request(:get, "http://some-tps-addr:5151/lrps/#{app.guid}-#{app.version}").to_return(status: 500, body: " ")
          end

          it "raises DiegoUnavailable" do
            expect { client.lrp_instances(app) }.to raise_error(Unavailable, /unavailable/i)
          end
        end

        describe "timing out" do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:get).and_return(double(:http_response, body: '{}', code: '200'))
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

      context "when there are no tps addresses registered" do
        before do
          allow(service_registry).to receive(:tps_addrs).and_return([])
        end

        it "raises Diego::Unavailable" do
          expect { client.lrp_instances(app) }.to raise_error(Unavailable, "Diego runtime is unavailable.")
        end
      end
    end
  end
end
