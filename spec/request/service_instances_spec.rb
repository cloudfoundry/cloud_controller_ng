require 'spec_helper'

RSpec.describe 'Service Instances' do
  let(:user_email) { 'user@email.example.com' }
  let(:user_name) { 'username' }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:admin_header) { admin_headers_for(user, email: user_email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:target_space) { VCAP::CloudController::Space.make }
  let!(:service_instance1) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'rabbitmq') }
  let!(:service_instance2) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'redis') }
  let!(:service_instance3) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'mysql') }

  describe 'GET /v3/service_instances' do
    it 'returns a paginated list of service instances the user has access to' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      get '/v3/service_instances?per_page=2&order_by=name', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 3,
            'total_pages' => 2,
            'first' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=name&page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=name&page=2&per_page=2"
            },
            'next' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=name&page=2&per_page=2"
            },
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => service_instance3.guid,
              'name' => service_instance3.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
            },
            {
              'guid' => service_instance1.guid,
              'name' => service_instance1.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
            }
          ]
        }
      )
    end

    it 'returns a paginated list of service instances filtered by name' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      get '/v3/service_instances?per_page=2&names=redis', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/service_instances?names=redis&page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/service_instances?names=redis&page=1&per_page=2"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => service_instance2.guid,
              'name' => service_instance2.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
            }
          ]
        }
      )
    end

    context 'when a user has access to a shared service instance' do
      before do
        service_instance1.add_shared_space(target_space)
      end

      it 'returns a paginated list of service instances the user has access to' do
        set_current_user_as_role(role: 'space_developer', org: target_space.organization, space: target_space, user: user)
        get '/v3/service_instances?per_page=2&order_by=name', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/service_instances?order_by=name&page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/service_instances?order_by=name&page=1&per_page=2"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => service_instance1.guid,
                'name' => service_instance1.name,
                'created_at' => iso8601,
                'updated_at' => iso8601,
              }
            ]
          }
        )
      end
    end
  end

  describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
    before do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    it 'shares the service instance with the target space' do
      share_request = {
        'data' => [
          { 'guid' => target_space.guid }
        ]
      }

      post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => target_space.guid }
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
          'related' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/shared_spaces" },
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.service_instance.share',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             service_instance1.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance1.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guids']).to eq([target_space.guid])
    end

    context 'when the service offering has shareable false' do
      before do
        service_instance1.service.extra = { shareable: false }.to_json
        service_instance1.service.save
      end

      it 'fails to share' do
        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header

        expect(last_response.status).to eq(400)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['errors'].first['code']).to eq(390003)
        expect(parsed_response['errors'].first['title']).to eq('CF-ServiceShareIsDisabled')
      end
    end
  end

  describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space-guid' do
    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
      end

      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)

      share_request = {
        'data' => [
          { 'guid' => target_space.guid }
        ]
      }

      post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
      expect(last_response.status).to eq(200)
    end

    it 'unshares the service instance from the target space' do
      delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.service_instance.unshare',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             service_instance1.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance1.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)
    end

    it 'deletes associated bindings in target space when service instance is unshared' do
      process = VCAP::CloudController::ProcessModelFactory.make(diego: false, space: target_space)
      service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: service_instance1, app: process.app, credentials: { secret: 'key' })

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(200)

      delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(404)
    end
  end
end
