require 'rack/test'
require 'spec_helper'

describe 'v3 service bindings' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config     = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

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
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
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
      service_binding_guid = MultiJson.load(last_response.body)['guid']

      expect(last_response.status).to eq(201)

      get(
        "/v3/service_bindings/#{service_binding_guid}",
        nil,
        user_headers
      )

      expect(MultiJson.load(last_response.body)['data']['credentials']['username']).to eq('cool_user')
    end
  end

  describe 'when the service is user provided' do
    let(:service_instance_guid) do
      post(
        '/v2/user_provided_service_instances',
        {
          name:       'test_ups',
          space_guid: space_guid,
          credentials: {
            'username': 'user_provided_username'
          }
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
      service_binding_guid = MultiJson.load(last_response.body)['guid']

      expect(last_response.status).to eq(201)

      get(
        "/v3/service_bindings/#{service_binding_guid}",
        nil,
        user_headers
      )

      expect(MultiJson.load(last_response.body)['data']['credentials']['username']).to eq('user_provided_username')
    end
  end
end
