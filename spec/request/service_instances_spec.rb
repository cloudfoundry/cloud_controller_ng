require 'spec_helper'

RSpec.describe 'Service Instances' do
  describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { admin_headers_for(user) }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

    before do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    it 'shares the service instance with the target space' do
      share_request = {
        data: [
          { guid: target_space.guid }
        ]
      }

      post "/v3/service_instances/#{service_instance.guid}/relationships/shared_spaces", share_request.to_json, user_header

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
    end
  end
end
