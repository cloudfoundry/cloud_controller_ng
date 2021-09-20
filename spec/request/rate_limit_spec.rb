require 'spec_helper'

RSpec.describe 'Rate Limiting' do
  before do
    TestConfig.override(
      rate_limiter: {
        enabled: true,
        general_limit: 10,
        unauthenticated_limit: 2,
        reset_interval_in_minutes: 60,
        service_instance_limit: 5,
        service_instance_reset_interval_in_minutes: 30
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
    context 'using service instance endpoints' do
      context 'with POST methods' do
        it 'uses the service instance limit on v2' do
          5.times do |n|
            post('/v2/service_instances', nil, user_headers)
            expect(last_response.status).to eq(400)
          end

          post('/v2/service_instances', nil, user_headers)
          expect(last_response.status).to eq(429)
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response.first.second).to eq('Service Instance Rate Limit Exceeded')
        end
        it 'uses the service instance limit on v3' do
          5.times do |n|
            post('/v3/service_instances', nil, user_headers)
            expect(last_response.status).to eq(422)
          end

          post('/v3/service_instances', nil, user_headers)
          expect(last_response.status).to eq(429)
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['errors'].first['detail']).to eq('Service Instance Rate Limit Exceeded')
        end
      end

      context 'with GET methods' do
        it 'uses the general limit on v2' do
          10.times do |n|
            get('/v2/service_instances', nil, user_headers)
            expect(last_response.status).to eq(200)
          end

          get('/v2/service_instances', nil, user_headers)
          expect(last_response.status).to eq(429)
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response.first.second).to eq('Rate Limit Exceeded')
        end
        it 'uses the general limit on v3' do
          10.times do |n|
            get('/v3/service_instances', nil, user_headers)
            expect(last_response.status).to eq(200)
          end

          get('/v3/service_instances', nil, user_headers)
          expect(last_response.status).to eq(429)
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['errors'].first['detail']).to eq('Rate Limit Exceeded')
        end
      end

      context 'that require existing service_instances' do
        # let(:user) { VCAP::CloudController::User.make }
        let(:org) { VCAP::CloudController::Organization.make }
        let(:space) { VCAP::CloudController::Space.make(organization: org) }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
        let(:guid) { instance.guid }

        context 'with PUT methods' do
          it 'uses the service instance limit on v2' do
            5.times do |n|
              put("/v2/service_instances/#{guid}", nil, user_headers)
              expect(last_response.status).to eq(400)
            end

            put("/v2/service_instances/#{guid}", nil, user_headers)
            expect(last_response.status).to eq(429)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response.first.second).to eq('Service Instance Rate Limit Exceeded')
          end
        end
        context 'with PATCH methods' do
          it 'uses the service instance limit on v3' do
            5.times do |n|
              patch("/v3/service_instances/#{guid}", nil, user_headers)
              expect(last_response.status).to eq(200)
            end

            patch("/v3/service_instances/#{guid}", nil, user_headers)
            expect(last_response.status).to eq(429)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['errors'].first['detail']).to eq('Service Instance Rate Limit Exceeded')
          end
        end
      end
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
    it 'uses the unauthenticated limit on service_instances endpoints' do
      2.times do |n|
        get '/v3/service_instances', nil, {}
        expect(last_response.status).to eq(401), "rate limited after #{n} requests"
      end

      get '/v3/service_instances', nil, {}
      expect(last_response.status).to eq(429)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['errors'].first['detail']).to include('Rate Limit Exceeded: Unauthenticated requests from this IP address have exceeded the limit')
    end
  end
end
