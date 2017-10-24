require 'spec_helper'

RSpec.describe 'Service Instances' do
  let(:user_email) { 'user@email.example.com' }
  let(:user_name) { 'sharer_username' }
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user, email: user_email, user_name: user_name) }
  let(:target_space) { VCAP::CloudController::Space.make }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

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

      post "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces", share_request.to_json, admin_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => target_space.guid }
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces" },
          'related' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance.guid}/shared_spaces" },
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
        actee:             service_instance.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance.name,
        space_guid:        service_instance.space.guid,
        organization_guid: service_instance.space.organization.guid
      })
      expect(event.metadata['target_space_guids']).to eq([target_space.guid])
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

      post "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces", share_request.to_json, admin_header
      expect(last_response.status).to eq(200)
    end

    it 'unshares the service instance from the target space' do
      delete "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.service_instance.unshare',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             service_instance.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance.name,
        space_guid:        service_instance.space.guid,
        organization_guid: service_instance.space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)
    end

    it 'deletes associated bindings in target space when service instance is unshared' do
      process = VCAP::CloudController::ProcessModelFactory.make(diego: false, space: target_space)
      service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: process.app, credentials: { secret: 'key' })

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(200)

      delete "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(404)
    end
  end
end
