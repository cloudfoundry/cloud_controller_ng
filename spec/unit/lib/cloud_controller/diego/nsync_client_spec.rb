require 'spec_helper'

module VCAP::CloudController::Diego
  describe NsyncClient do
    let(:content_type_header) { { 'Content-Type' => 'application/json' } }
    let(:app) { VCAP::CloudController::AppFactory.make }
    let(:process_guid) { ProcessGuid.from_app(app) }
    let(:desire_message) { MultiJson.dump({ process_guid: process_guid }) }

    subject(:client) { NsyncClient.new(TestConfig.config) }

    describe '#desire_app' do
      let(:desire_app_url) { "#{TestConfig.config[:diego_nsync_url]}/v1/apps/#{process_guid}" }

      context 'when there is an nsync url configured' do
        context 'when an endpoint is available' do
          before do
            stub_request(:put, desire_app_url).to_return(status: 202)
          end

          it 'calls nsync with the desire message' do
            expect(client.desire_app(process_guid, desire_message)).to be_nil
            expect(a_request(:put, desire_app_url).with(body: desire_message, headers: content_type_header)).to have_been_made.once
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:put, desire_app_url).to_raise(Errno::ECONNREFUSED)

            expect { client.desire_app(process_guid, desire_message) }.to raise_error(VCAP::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:put, desire_app_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.desire_app(process_guid, desire_message) }.to raise_error(VCAP::Errors::ApiError, /desire app failed: 500/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:put).and_return(double(:http_response, body: '{}', code: '202'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.desire_app(process_guid, desire_message)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.desire_app(process_guid, desire_message)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when the nsync url is missing' do
        before do
          TestConfig.override(diego_nsync_url: nil)
        end

        it 'raises RunnerUnavailable' do
          expect { client.desire_app(process_guid, desire_message) }.to raise_error(VCAP::Errors::ApiError, /invalid config/)
        end
      end
    end

    describe '#stop_app' do
      let(:stop_app_url) { "#{TestConfig.config[:diego_nsync_url]}/v1/apps/#{process_guid}" }

      context 'when there is an nsync url configured' do
        context 'when the endpoint is available' do
          before do
            stub_request(:delete, stop_app_url).to_return(status: 202)
          end

          it 'calls the nsync with a delete request' do
            expect(client.stop_app(process_guid)).to be_nil
            expect(a_request(:delete, stop_app_url).with(body: nil, headers: content_type_header)).to have_been_made.once
          end

          context 'when nsync returns a 404' do
            before do
              stub_request(:delete, stop_app_url).to_return(status: 404)
            end

            it 'does not raise an error' do
              expect { client.stop_app(process_guid) }.to_not raise_error
            end
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:delete, stop_app_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stop_app(process_guid) }.to raise_error(VCAP::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:delete, stop_app_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.stop_app(process_guid) }.to raise_error(VCAP::Errors::ApiError, /stop app failed: 500/i)
          end
        end
      end
    end

    describe '#stop_index' do
      let(:index) { 1 }
      let(:stop_index_url) { "#{TestConfig.config[:diego_nsync_url]}/v1/apps/#{process_guid}/index/#{index}" }

      context 'when there is an nsync url configured' do
        context 'when the endpoint is available' do
          before do
            stub_request(:delete, stop_index_url).to_return(status: 202)
          end

          it 'calls the nsync with a delete request' do
            expect(client.stop_index(process_guid, index)).to be_nil
            expect(a_request(:delete, stop_index_url).with(body: nil, headers: content_type_header)).to have_been_made.once
          end

          context 'when nsync returns a 404' do
            before do
              stub_request(:delete, stop_index_url).to_return(status: 404)
            end

            it 'does not raise an error' do
              expect { client.stop_index(process_guid, index) }.to_not raise_error
            end
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:delete, stop_index_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stop_index(process_guid, index) }.to raise_error(VCAP::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:delete, stop_index_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.stop_index(process_guid, index) }.to raise_error(VCAP::Errors::ApiError, /stop index failed: 500/i)
          end
        end
      end

      context 'when the nsync url is missing' do
        before do
          TestConfig.override(diego_nsync_url: nil)
        end

        it 'raises RunnerUnavailable' do
          expect { client.stop_index(process_guid, index) }.to raise_error(VCAP::Errors::ApiError, /invalid config/)
        end
      end
    end
  end
end
