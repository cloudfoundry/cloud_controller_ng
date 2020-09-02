require 'spec_helper'
require 'request_spec_shared_examples'
require 'controllers/v3/space_features_controller'

RSpec.describe 'Space Features' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make(allow_ssh: true) }
  let(:org) { space.organization }

  describe 'GET /v3/spaces/:guid/features' do
    let(:api_call) do
      ->(user_header) { get "/v3/spaces/#{space.guid}/features", nil, user_header }
    end

    let(:space_features_json) do
      {
        resources: [
          {
            'name' => 'ssh',
            'description' => 'Enable SSHing into apps in the space.',
            'enabled' => true
          }
        ]
      }
    end

    let(:expected_codes_and_responses) do
      responses_for_space_restricted_single_endpoint(space_features_json)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'GET /v3/spaces/:guid/features/:name' do
    let(:api_call) do
      ->(user_header) { get "/v3/spaces/#{space.guid}/features/ssh", nil, user_header }
    end

    let(:space_ssh_feature_json) do
      {
        'name' => 'ssh',
        'description' => 'Enable SSHing into apps in the space.',
        'enabled' => true
      }
    end

    let(:expected_codes_and_responses) do
      responses_for_space_restricted_single_endpoint(space_ssh_feature_json)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'PATCH /v3/spaces/:guid/features/:name' do
    let(:api_call) do
      ->(user_header) { patch "/v3/spaces/#{space.guid}/features/ssh", params.to_json, user_header }
    end

    let(:params) do
      {
        'enabled' => false
      }
    end

    let(:space_ssh_feature_json) do
      {
        'name' => 'ssh',
        'description' => 'Enable SSHing into apps in the space.',
        'enabled' => false
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new(code: 403)
      h['admin'] = { code: 200, response_object: space_ssh_feature_json }
      h['space_manager'] = { code: 200, response_object: space_ssh_feature_json }
      h['org_manager'] = { code: 200, response_object: space_ssh_feature_json }
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
      h['no_role'] = { code: 404 }
      h
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when the space does not exist' do
      let(:fake_space_guid) { 'grapefruit' }

      it 'raises an error' do
        patch "/v3/spaces/#{fake_space_guid}/features/ssh", params.to_json, admin_headers

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Space not found')
      end
    end
  end

  context 'when the feature does not exist' do
    it 'raises an error' do
      get "/v3/spaces/#{space.guid}/features/bogus-feature", nil, admin_headers

      expect(last_response).to have_status_code(404)
      expect(last_response).to have_error_message('Feature not found')
    end
  end
end
