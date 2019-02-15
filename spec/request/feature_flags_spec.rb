require 'spec_helper'

RSpec.describe 'Feature Flags Request' do
  describe 'GET /v3/feature_flags' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:flag_defaults) { VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS }
    let(:flag_names_sorted) { flag_defaults.keys.sort }

    it 'returns feature flags in alphabetical order' do
      get '/v3/feature_flags', nil, headers

      expect(last_response.status).to eq(200)
      flag_names_in_response = parsed_response['resources'].map { |flag| flag['name'] }
      expect(flag_names_in_response).to eq(flag_names_sorted.map(&:to_s))
    end
  end

  describe 'GET /v3/feature_flags/:name' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    context 'there is not an override' do
      it 'returns details of the requested feature flag when ' do
        get '/v3/feature_flags/diego_docker', nil, headers
        expect(last_response.status).to eq 200
        expect(parsed_response).to be_a_response_like(
          {
            'updated_at' => nil,
            'name' => 'diego_docker',
            'enabled' => false,
            'custom_error_message' => nil,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/feature_flags/diego_docker"
              }
            }
          }
        )
      end
    end

    context 'there is an override' do
      let(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: 'error') }
      it 'returns details of the requested feature flag when there is an override' do
        get "/v3/feature_flags/#{feature_flag.name}", nil, headers
        expect(last_response.status).to eq 200
        expect(parsed_response).to be_a_response_like(
          {
            'updated_at' => iso8601,
            'name' => feature_flag.name,
            'enabled' => feature_flag.enabled,
            'custom_error_message' => feature_flag.error_message,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/feature_flags/diego_docker"
              }
            }
          }
        )
      end
    end
  end
end
