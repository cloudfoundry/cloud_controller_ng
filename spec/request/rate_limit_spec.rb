require 'spec_helper'

RSpec.describe 'Rate Limiting' do
  before do
    TestConfig.override(
      rate_limiter: {
        enabled: true,
        general_limit: 10,
        total_general_limit: 100,
        unauthenticated_limit: 2,
        total_unauthenticated_limit: 20,
        reset_interval_in_minutes: 60
      }
    )
  end

  context 'as a user' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:user)  { make_developer_for_space(space) }

    let(:user_headers) do
      headers_for(user, user_name: 'roto')
    end

    it 'uses the general limit' do
      10.times do |n|
        get '/v3/spaces', nil, user_headers
        expect(last_response.status).to eq(200), "rate limited after #{n} requests"
      end

      get '/v3/spaces', nil, user_headers
      expect(last_response.status).to eq(429)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to eq('Rate Limit Exceeded')
    end
  end

  context 'as a UAA client' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:client)  {
      user = make_developer_for_space(space)
      user.update(is_oauth_client: true)
      user
    }

    let(:client_headers) do
      headers_for(client, client: true)
    end

    it 'uses the general limit' do
      10.times do |n|
        get '/v3/spaces', nil, client_headers
        expect(last_response.status).to eq(200), "rate limited after #{n} requests"
      end

      get '/v3/spaces', nil, client_headers
      expect(last_response.status).to eq(429)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to eq('Rate Limit Exceeded')
    end
  end

  context 'as an unauthenticated user' do
    it 'uses the unauthenticated limit' do
      2.times do |n|
        get '/v3/spaces', nil, {}
        expect(last_response.status).to eq(401), "rate limited after #{n} requests"
      end

      get '/v3/spaces', nil, {}
      expect(last_response.status).to eq(429)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to include('Rate Limit Exceeded: Unauthenticated requests from this IP address have exceeded the limit')
    end
  end
end
