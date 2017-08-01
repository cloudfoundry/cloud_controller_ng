require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RootController do
    describe 'GET /' do
      it 'returns a link to itself' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expected_uri = link_prefix.to_s
        expect(hash['links']['self']['href']).to eq(expected_uri)
      end

      it 'returns a cloud controller v2 link with metadata' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expected_uri = "#{link_prefix}/v2"
        expect(hash['links']['cloud_controller_v2']).to eq(
          {
            'href' => expected_uri,
            'meta' => {
              'version' => VCAP::CloudController::Constants::API_VERSION
            }
          }
        )
      end

      it 'returns a cloud controller v3 link with metadata' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expected_uri = "#{link_prefix}/v3"
        expect(hash['links']['cloud_controller_v3']).to eq(
          {
            'href' => expected_uri,
            'meta' => {
              'version' => VCAP::CloudController::Constants::API_VERSION_V3
            }
          }
        )
      end

      it 'returns a link to UAA' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expect(hash['links']['uaa']['href']).to eq(TestConfig.config[:uaa][:url])
      end

      it 'returns a link to network-policy v0 API' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expected_uri = "#{link_prefix}/networking/v0/external"
        expect(hash['links']['network_policy_v0']['href']).to eq(expected_uri)
      end

      it 'returns a link to network-policy v1 API' do
        get '/'
        hash = MultiJson.load(last_response.body)
        expected_uri = "#{link_prefix}/networking/v1/external"
        expect(hash['links']['network_policy_v1']['href']).to eq(expected_uri)
      end

      it 'returns a link to the logging API' do
        expected_uri = 'wss://doppler.my-super-cool-cf.com:1234'
        TestConfig.override(doppler: { url: expected_uri })

        get '/'
        hash = MultiJson.load(last_response.body)
        expect(hash['links']['logging']['href']).to eq(expected_uri)
      end
    end
  end
end
