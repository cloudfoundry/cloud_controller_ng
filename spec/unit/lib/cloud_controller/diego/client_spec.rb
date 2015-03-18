require 'spec_helper'

module VCAP::CloudController::Diego
  describe Client do
    let(:app) { VCAP::CloudController::AppFactory.make }
    subject(:client) { Client.new(TestConfig.config) }

    describe 'getting app instance information' do
      context 'when there is a tps url configured' do
        context 'and the first endpoint returns instance info' do
          before do
            stub_request(:get, "http://tps.service.dc1.consul:1518/lrps/#{app.guid}-#{app.version}").to_return(
              status: 200,
              body: [{ process_guid: 'abc', instance_guid: '123', index: 0, state: 'running', since_in_ns: '1257894000000000001' },
                     { process_guid: 'abc', instance_guid: '456', index: 1, state: 'starting', since_in_ns: '1257895000000000001' },
                     { process_guid: 'abc', instance_guid: '789', index: 1, state: 'crashed', details: 'down-hard', since_in_ns: '1257896000000000001' }].to_json)
          end

          it "reports each instance's index, state, since, process_guid, instance_guid" do
            expect(client.lrp_instances(app)).to eq([
              { process_guid: 'abc', instance_guid: '123', index: 0, state: 'RUNNING', since: 1257894000 },
              { process_guid: 'abc', instance_guid: '456', index: 1, state: 'STARTING', since: 1257895000 },
              { process_guid: 'abc', instance_guid: '789', index: 1, state: 'CRASHED', details: 'down-hard', since: 1257896000 }
            ])
          end
        end

        context 'when the TPS endpoint is unavailable' do
          it 'retries and eventually raises Diego::Unavailable' do
            stub = stub_request(:get, "http://tps.service.dc1.consul:1518/lrps/#{app.guid}-#{app.version}").to_raise(Errno::ECONNREFUSED)

            expect { client.lrp_instances(app) }.to raise_error(Unavailable, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the TPS endpoint fails' do
          before do
            stub_request(:get, "http://tps.service.dc1.consul:1518/lrps/#{app.guid}-#{app.version}").to_return(status: 500, body: ' ')
          end

          it 'raises DiegoUnavailable' do
            expect { client.lrp_instances(app) }.to raise_error(Unavailable, /unavailable/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:get).and_return(double(:http_response, body: '{}', code: '200'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.lrp_instances(app)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.lrp_instances(app)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when there is no tps url' do
        before do
          TestConfig.override(diego_tps_url: nil)
        end

        it 'raises Diego::Unavailable' do
          expect { client.lrp_instances(app) }.to raise_error(Unavailable, 'Diego runtime is unavailable.')
        end
      end
    end
  end
end
