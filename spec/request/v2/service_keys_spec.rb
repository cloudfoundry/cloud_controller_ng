require 'spec_helper'

RSpec.describe 'ServiceKeys' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/service_keys' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let!(:service_key1) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance, credentials: { secret: 'key' }) }
    let!(:service_key2) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance, credentials: { secret: 'key' }) }

    it 'lists service keys' do
      get '/v2/service_keys', nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 2,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'metadata' => {
                'guid' => service_key1.guid,
                'url' => "/v2/service_keys/#{service_key1.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'service_instance_guid' => service_key1.service_instance.guid,
                'credentials' => { 'secret' => 'key' },
                'name' => service_key1.name,
                'service_instance_url' => "/v2/service_instances/#{service_key1.service_instance.guid}",
                'service_key_parameters_url' => "/v2/service_keys/#{service_key1.guid}/parameters",
              }
            },
            {
              'metadata' => {
                'guid' => service_key2.guid,
                'url' => "/v2/service_keys/#{service_key2.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'service_instance_guid' => service_key2.service_instance.guid,
                'credentials' => { 'secret' => 'key' },
                'name' => service_key2.name,
                'service_instance_url' => "/v2/service_instances/#{service_key2.service_instance.guid}",
                'service_key_parameters_url' => "/v2/service_keys/#{service_key2.guid}/parameters",
              }
            }
          ]
        }
      )
    end
  end

  describe 'GET /v2/service_keys/:guid' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let!(:service_key1) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance, credentials: { secret: 'key' }, name: 'key') }

    it 'displays the service key' do
      get "/v2/service_keys/#{service_key1.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid' => service_key1.guid,
            'url' => "/v2/service_keys/#{service_key1.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'service_instance_guid' => service_instance.guid,
            'credentials' => { 'secret' => 'key' },
            'name' => 'key',
            'service_instance_url' => "/v2/service_instances/#{service_instance.guid}",
            'service_key_parameters_url' => "/v2/service_keys/#{service_key1.guid}/parameters"
          }
        }
      )
    end
  end

  describe 'GET /v2/service_keys/:guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(bindings_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    let!(:service_key) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        fb.parameters = {
          parameters: {
            top_level_param: {
              nested_param: true,
            },
            another_param: 'some-value',
          },
          credentials:
          {
            secret: 'key'
          }
        }
        fb
      end
    end

    it 'displays the service key parameters' do
      get "/v2/service_keys/#{service_key.guid}/parameters", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = last_response.body
      expect(MultiJson.load(parsed_response)).to be_a_response_like(
        {
          'top_level_param' => {
            'nested_param' => true,
          },
          'another_param' => 'some-value',
        }
      )
    end
  end
end
