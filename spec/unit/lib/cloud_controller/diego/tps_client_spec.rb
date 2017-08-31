require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe TPSClient do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make }
    let(:process2) { VCAP::CloudController::ProcessModelFactory.make }

    let(:process_guid) { "#{process.guid}-#{process.version}" }
    let(:process_guid2) { "#{process2.guid}-#{process2.version}" }

    let(:tps_status_url) { "#{TestConfig.config[:diego][:tps_url]}/v1/actual_lrps/#{process_guid}" }
    let(:tps_stats_url) { "#{TestConfig.config[:diego][:tps_url]}/v1/actual_lrps/#{process_guid}/stats" }
    let(:tps_bulk_status_url) { "#{TestConfig.config[:diego][:tps_url]}/v1/bulk_actual_lrp_status?guids=#{process_guid},#{process_guid2}" }

    subject(:client) { TPSClient.new(TestConfig.config_instance) }

    describe 'fetching lrp status' do
      context 'when there is a tps url configured' do
        context 'and the first attempt returns lrp status' do
          before do
            stub_request(:get, tps_status_url).to_return(status: 200,
                                                         body: { 'cool' => 'instances' }.to_json)
          end

          it "reports each instance's index, state, since, process_guid, instance_guid, and details" do
            expected_lrp_instances = { cool: 'instances' }

            expect(client.lrp_instances(process)).to eq(expected_lrp_instances)
          end
        end

        context 'when the TPS endpoint is unavailable' do
          it 'retries and eventually raises InstancesUnavailable' do
            stub = stub_request(:get, tps_status_url).to_raise(Errno::ECONNREFUSED)

            expect { client.lrp_instances(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the TPS endpoint 404s' do
          before do
            stub_request(:get, tps_status_url).to_return(status: 404, body: 'Could not find it')
          end

          it 'returns an empty array' do
            expect(client.lrp_instances(process)).to eq([])
          end
        end

        context 'when the TPS endpoint fails' do
          before do
            stub_request(:get, tps_status_url).to_return(status: 500, body: 'This Broke')
          end

          it 'raises InstancesUnavailable' do
            expect {
              client.lrp_instances(process)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /response code: 500, response body: This Broke/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:get2).and_return(double(:http_response, body: '{}', code: '200'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.lrp_instances(process)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.lrp_instances(process)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when there is no tps url' do
        before do
          TestConfig.override(diego: { tps_url: nil })
        end

        it 'raises InstancesUnavailable' do
          expect {
            client.lrp_instances(process)
          }.to raise_error(CloudController::Errors::InstancesUnavailable, 'TPS URL not configured')
        end
      end
    end

    describe 'fetching lrp stats' do
      context 'when there is a tps stats url is configured' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:auth_token).and_return('my-token')
        end

        context 'and the first attempt returns instance info with stats' do
          before do
            stub_request(:get, tps_stats_url).with(
              headers: { 'Authorization' => 'my-token' }
            ).to_return(status: 200, body: { 'foo' => 'bar', 'lisa' => 'baz' }.to_json)
          end

          it 'returns a symbolized hash of the JSON body' do
            expected_instance_stats = {
              foo: 'bar',
              lisa: 'baz'
            }

            expect(client.lrp_instances_stats(process)).to eq(expected_instance_stats)
          end
        end

        context 'when the TPS endpoint is unavailable' do
          it 'retries and eventually raises InstancesUnavailable' do
            stub = stub_request(:get, tps_stats_url).to_raise(Errno::ECONNREFUSED)

            expect {
              client.lrp_instances_stats(process)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the TPS endpoint 404s' do
          before do
            stub_request(:get, tps_stats_url).to_return(status: 404, body: 'Could not find it')
          end

          it 'returns an empty array' do
            expect(client.lrp_instances_stats(process)).to eq([])
          end
        end

        context 'when the TPS endpoint fails' do
          before do
            stub_request(:get, tps_stats_url).to_return(status: 500, body: ' ')
          end

          it 'raises InstancesUnavailable' do
            expect {
              client.lrp_instances_stats(process)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /response code: 500/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:get2).and_return(double(:http_response, body: '{}', code: '200'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.lrp_instances_stats(process)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.lrp_instances_stats(process)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when there is no tps url' do
        before do
          TestConfig.override(diego: { tps_url: nil })
        end

        it 'raises InstancesUnavailable' do
          expect {
            client.lrp_instances_stats(process)
          }.to raise_error(CloudController::Errors::InstancesUnavailable, 'TPS URL not configured')
        end
      end
    end

    describe 'fetching bulk lrp status' do
      context 'when there is a tps url configured' do
        context 'and the first attempt returns' do
          before do
            stub_request(:get, tps_bulk_status_url).to_return(
              status: 200,
              body: { 'cool' => 'processes' }.to_json)
          end

          it 'returns a map of application guid to instance statuses' do
            expected_lrp_instance_map = { 'cool' => 'processes' }

            expect(client.bulk_lrp_instances([process, process2])).to eq(expected_lrp_instance_map)
          end
        end

        context 'when an empty array is passed in' do
          it 'returns an empty map' do
            result = client.bulk_lrp_instances([])
            expect(result).to eq({})
          end

          it 'does not make a request' do
            stub = stub_request(:get, tps_bulk_status_url).to_raise("this shouldn't be called")

            expect { client.bulk_lrp_instances([]) }.not_to raise_error
            expect(stub).not_to have_been_requested
          end
        end

        context 'when the TPS endpoint is unavailable' do
          it 'retries and eventually raises InstancesUnavailable' do
            stub = stub_request(:get, tps_bulk_status_url).to_raise(Errno::ECONNREFUSED)

            expect { client.bulk_lrp_instances([process, process2]) }.to raise_error(CloudController::Errors::InstancesUnavailable, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the TPS endpoint fails' do
          before do
            stub_request(:get, tps_bulk_status_url).to_return(status: 500, body: 'This Broke')
          end

          it 'raises InstancesUnavailable' do
            expect {
              client.bulk_lrp_instances([process, process2])
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /response code: 500, response body: This Broke/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:get2).and_return(double(:http_response, body: '{}', code: '200'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.bulk_lrp_instances([process])
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.bulk_lrp_instances([process])
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when there is no tps url' do
        before do
          TestConfig.override(diego: { tps_url: nil })
        end

        it 'raises InstancesUnavailable' do
          expect {
            client.bulk_lrp_instances([process])
          }.to raise_error(CloudController::Errors::InstancesUnavailable, 'TPS URL not configured')
        end
      end
    end
  end
end
