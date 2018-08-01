require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RootController do
    let(:scheme) { TestConfig.config[:external_protocol] }
    let(:host) { TestConfig.config[:external_domain] }
    let(:link_prefix) { "#{scheme}://#{host}" }

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
    end
  end
end
