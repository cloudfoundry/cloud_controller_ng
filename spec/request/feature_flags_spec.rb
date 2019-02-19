require 'spec_helper'

RSpec.describe 'Feature Flags Request' do
  describe 'GET /v3/feature_flags' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:flag_defaults) { VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS }
    let(:flag_names_sorted) { flag_defaults.keys.sort }

    it 'returns 200 OK' do
      get '/v3/feature_flags', nil, headers

      expect(last_response.status).to eq(200)
    end

    it 'returns feature flags in alphabetical order' do
      get '/v3/feature_flags', nil, headers
      flag_names_in_response = parsed_response['resources'].map { |flag| flag['name'] }
      expect(flag_names_in_response).to eq(flag_names_sorted.map(&:to_s))
    end

    context 'when there are no overrides' do
    end

    context 'when there are overrides' do
    end

    context 'when order_by direction is descending' do
      it 'returns feature flags in reverse alphabetical order' do
        pending
        get '/v3/feature_flags?order_by=-name', nil, headers
        flag_names_in_response = parsed_response['resources'].map { |flag| flag['name'] }
        expect(flag_names_in_response).to eq(flag_names_sorted)
      end
    end
  end
end
