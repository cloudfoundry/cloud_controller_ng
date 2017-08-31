require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe StagerClient do
    let(:content_type_header) { { 'Content-Type' => 'application/json' } }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make }
    let(:staging_guid) { process.latest_droplet.guid }
    let(:staging_url) { "#{TestConfig.config[:diego][:stager_url]}/v1/staging/#{staging_guid}" }

    subject(:client) { StagerClient.new(TestConfig.config_instance) }

    describe 'making a staging request' do
      let(:staging_message) { { app_id: process.guid } }

      context 'when there is a stager url configured' do
        context 'when the stager endpoint is available' do
          before do
            stub_request(:put, staging_url).to_return(status: 202)
          end

          it 'calls the stager with the staging message' do
            expect(client.stage(staging_guid, staging_message)).to be_nil
            expect(a_request(:put, staging_url).with(body: staging_message, headers: content_type_header)).to have_been_made.once
          end
        end

        context 'when the stager endpoint is unavailable' do
          it 'retries and eventually raises StagerUnavailable' do
            stub = stub_request(:put, staging_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the stager endpoint fails with no error data' do
          before do
            stub_request(:put, staging_url).to_return(status: 500, body: '')
          end

          it 'raises StagerUnavailable' do
            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /staging failed: 500/i)
          end
        end

        context 'when the stager endpoint fails with error message' do
          before do
            stub_request(:put, staging_url).to_return(status: 500, body: '{"error":{"message":"missing docker registry"}}')
          end

          it 'raises Stager failed with message' do
            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /staging failed: missing docker registry/i)
          end
        end

        context 'when the stager endpoint fails with missing error message' do
          before do
            stub_request(:put, staging_url).to_return(status: 500, body: '{"detected_start_command":null, "error":{"id":"StagingError"}}')
          end

          it 'raises Stager failed with code' do
            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /staging failed: 500/i)
          end
        end

        context 'when the stager endpoint fails with missing error' do
          before do
            stub_request(:put, staging_url).to_return(status: 500, body: '{"detected_start_command":null}')
          end

          it 'raises Stager failed with code' do
            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /staging failed: 500/i)
          end
        end

        context 'when the stager endpoint fails with invalid JSON body' do
          before do
            stub_request(:put, staging_url).to_return(status: 500, body: 'invalid json')
          end

          it 'raises Stager failed with code' do
            expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /staging failed: 500/i)
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
            client.stage(staging_guid, staging_message)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.stage(staging_guid, staging_message)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when the stager url is missing' do
        before do
          TestConfig.override(diego: { stager_url: nil })
        end

        it 'raises StagerUnavailable' do
          expect { client.stage(staging_guid, staging_message) }.to raise_error(CloudController::Errors::ApiError, /invalid config/)
        end
      end
    end

    describe 'stopping a staging task' do
      context 'when there is a stager url configured' do
        context 'when the stager endpoint is available' do
          before do
            stub_request(:delete, staging_url).to_return(status: 202)
          end

          it 'calls the stager with a delete request' do
            expect(client.stop_staging(staging_guid)).to be_nil
            expect(a_request(:delete, staging_url).with(body: nil, headers: content_type_header)).to have_been_made.once
          end

          context 'when the stager returns a 404' do
            before do
              stub_request(:delete, staging_url).to_return(status: 404)
            end

            it 'does not raise an error' do
              expect { client.stop_staging(staging_guid) }.to_not raise_error
            end
          end
        end

        context 'when the stager endpoint is unavailable' do
          it 'retries and eventually raises StagerUnavailable' do
            stub = stub_request(:delete, staging_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stop_staging(staging_guid) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end
      end

      context 'when the stager url is missing' do
        before do
          TestConfig.override(diego: { stager_url: nil })
        end

        it 'raises StagerUnavailable' do
          expect { client.stop_staging(staging_guid) }.to raise_error(CloudController::Errors::ApiError, /invalid config/)
        end
      end
    end
  end
end
