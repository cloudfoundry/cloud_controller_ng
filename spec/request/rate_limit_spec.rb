require 'spec_helper'

RSpec.describe 'Rate Limiting' do
  before do
    TestConfig.override(
      rate_limiter: {
        enabled: true,
        per_process_general_limit: 10,
        global_general_limit: 100,
        per_process_unauthenticated_limit: 2,
        global_unauthenticated_limit: 20,
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
      parsed_response = Oj.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to eq('Rate Limit Exceeded')
    end
  end

  context 'as a UAA client' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:client)  do
      user = make_developer_for_space(space)
      user.update(is_oauth_client: true)
      user
    end

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
      parsed_response = Oj.load(last_response.body)
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
      parsed_response = Oj.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to include('Rate Limit Exceeded: Unauthenticated requests from this IP address have exceeded the limit')
    end
  end

  context 'as an admin' do
    let(:admin_headers) { admin_headers_for(VCAP::CloudController::User.make) }

    context 'when admin_limit is -1 (default, unlimited)' do
      it 'is not rate limited' do
        20.times do |n|
          get '/v3/spaces', nil, admin_headers
          expect(last_response.status).to eq(200), "rate limited after #{n} requests"
          expect(last_response.headers).not_to include('X-RateLimit-Limit')
        end
      end
    end

    context 'when admin_limit is set to a positive value' do
      before do
        TestConfig.override(
          rate_limiter: {
            enabled: true,
            per_process_general_limit: 10,
            global_general_limit: 100,
            per_process_unauthenticated_limit: 2,
            global_unauthenticated_limit: 20,
            per_process_admin_limit: 3,
            global_admin_limit: 30,
            reset_interval_in_minutes: 60
          }
        )
      end

      it 'uses the admin limit' do
        3.times do |n|
          get '/v3/spaces', nil, admin_headers
          expect(last_response.status).to eq(200), "rate limited after #{n} requests"
          expect(last_response.headers['X-RateLimit-Limit']).to eq('30')
        end

        get '/v3/spaces', nil, admin_headers
        expect(last_response.status).to eq(429)
      end

      it 'does not affect regular users' do
        4.times { get '/v3/spaces', nil, admin_headers }

        space = VCAP::CloudController::Space.make
        user = make_developer_for_space(space)
        user_headers = headers_for(user)

        get '/v3/spaces', nil, user_headers
        expect(last_response.status).to eq(200)
      end
    end
  end
end
