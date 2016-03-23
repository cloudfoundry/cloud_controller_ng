require 'spec_helper'

describe 'v3 service bindings' do
  let(:user) { VCAP::CloudController::User.make }

  let(:user_headers) do
    json_headers(headers_for(user))
  end

  let(:admin) do
    json_headers(admin_headers)
  end

  let(:space_guid) do
    post(
      '/v2/organizations',
      { 'name': 'development' }.to_json,
      admin_headers
    )
    organization_guid = MultiJson.load(last_response.body)['metadata']['guid']

    put(
      "/v2/organizations/#{organization_guid}/users/#{user.guid}",
      nil,
      admin_headers
    )

    put(
      "/v2/organizations/#{organization_guid}/managers/#{user.guid}",
      nil,
      admin_headers
    )

    post(
      '/v2/spaces',
      {
        name:              'development',
        organization_guid: organization_guid
      }.to_json,
      user_headers
    )
    space_guid = MultiJson.load(last_response.body)['metadata']['guid']

    put(
      "/v2/spaces/#{space_guid}/developers/#{user.guid}",
      nil,
      user_headers
    )

    space_guid
  end

  let(:app_guid) do
    post(
      '/v3/apps',
      {
        name:          'my_app',
        relationships: {
          space: { guid: space_guid }
        }
      }.to_json,
      user_headers
    )

    MultiJson.load(last_response.body)['guid']
  end

  describe 'when the service is managed' do
    let(:service_instance_guid) do
      post(
        '/v2/service_brokers',
        {
          name:          'cool-runnings',
          broker_url:    'https://example.com/foo/bar',
          auth_username: 'utako',
          auth_password: 'green'
        }.to_json,
        admin
      )

      get('/v2/service_plans', nil, admin_headers)
      service_plan_guid = MultiJson.load(last_response.body)['resources'][0]['metadata']['guid']

      put(
        "/v2/service_plans/#{service_plan_guid}",
        { 'public': true }.to_json,
        admin
      )

      post(
        '/v2/service_instances',
        {
          name:              'my-service-instance',
          service_plan_guid: service_plan_guid,
          space_guid:        space_guid
        }.to_json,
        user_headers
      )

      MultiJson.load(last_response.body)['metadata']['guid']
    end

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        fb.credentials = { 'username' => 'managed_username' }
        fb.syslog_drain_url = 'syslog://mydrain.example.com'
        fb
      end
    end

    it 'can be created' do
      post(
        '/v3/service_bindings',
        {
          type:          'app',
          relationships: {
            app:              { guid: app_guid },
            service_instance: { guid: service_instance_guid },
          }
        }.to_json,
        user_headers
      )

      parsed_response = MultiJson.load(last_response.body)
      guid = parsed_response['guid']

      expected_response = {
        'guid'       => guid,
        'type'       => 'app',
        'data'       => {
          'credentials' => {
            'username' => 'managed_username'
          },
          'syslog_drain_url' => 'syslog://mydrain.example.com'
        },
        'created_at' => iso8601,
        'updated_at' => nil,
        'links'      => {
          'self' => {
            'href' => "/v3/service_bindings/#{guid}"
          },
          'service_instance' => {
            'href' => "/v2/service_instances/#{service_instance_guid}"
          },
          'app' => {
            'href' => "/v3/apps/#{app_guid}"
          }
        }
      }

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
      expect(VCAP::CloudController::ServiceBindingModel.find(guid: guid)).to be_present

      get(
        "/v3/service_bindings/#{guid}",
        nil,
        user_headers
      )

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'DELETE /v3/service_bindings/:guid' do
      let!(:service_binding) { VCAP::CloudController::ServiceBindingModel.make }

      it 'deletes the service binding and returns a 204' do
        delete "/v3/service_bindings/#{service_binding.guid}", {}, admin_headers

        expect(last_response.status).to eq(204)
        expect(service_binding.exists?).to be_falsey
      end
    end
  end

  describe 'when the service is user provided' do
    let(:service_instance_guid) do
      post(
        '/v2/user_provided_service_instances',
        {
          name:             'test_ups',
          space_guid:       space_guid,
          credentials:      {
            'username': 'user_provided_username'
          },
          syslog_drain_url: 'syslog://drain.url.com'

        }.to_json,
        user_headers
      )

      MultiJson.load(last_response.body)['metadata']['guid']
    end

    it 'can be created' do
      post(
        '/v3/service_bindings',
        {
          type:          'app',
          relationships: {
            app:              { guid: app_guid },
            service_instance: { guid: service_instance_guid },
          }
        }.to_json,
        user_headers
      )

      parsed_response = MultiJson.load(last_response.body)
      guid = parsed_response['guid']

      expected_response = {
        'guid'       => guid,
        'type'       => 'app',
        'data'       => {
          'credentials' => {
            'username' => 'user_provided_username'
          },
          'syslog_drain_url' => 'syslog://drain.url.com'
        },
        'created_at' => iso8601,
        'updated_at' => nil,
        'links'      => {
          'self' => {
            'href' => "/v3/service_bindings/#{guid}"
          },
          'service_instance' => {
            'href' => "/v2/service_instances/#{service_instance_guid}"
          },
          'app' => {
            'href' => "/v3/apps/#{app_guid}"
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
      expect(VCAP::CloudController::ServiceBindingModel.find(guid: guid)).to be_present

      get(
        "/v3/service_bindings/#{guid}",
        nil,
        user_headers
      )

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'DELETE /v3/service_bindings/:guid' do
      let(:service_binding_guid) do
        post(
          '/v3/service_bindings',
          {
            type:          'app',
            relationships: {
              app:              { guid: app_guid },
              service_instance: { guid: service_instance_guid },
            }
          }.to_json,
          user_headers
        )

        MultiJson.load(last_response.body)['guid']
      end

      it 'deletes the service binding and returns a 204' do
        delete "/v3/service_bindings/#{service_binding_guid}", {}, admin_headers

        expect(last_response.status).to eq(204)

        get "/v3/service_bindings/#{service_binding_guid}", {}, admin_headers

        expect(last_response.status).to eq(404)
      end
    end
  end
end
