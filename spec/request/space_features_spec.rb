require 'spec_helper'
require 'request_spec_shared_examples'
require 'controllers/space_features_controller'

RSpec.describe 'Space Features' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make(allow_ssh: true) }
  let(:org) { space.organization }

  describe 'ssh feature' do
    describe 'GET /v3/spaces/:guid/features/ssh' do
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
        h = Hash.new(code: 200, response_object: space_ssh_feature_json)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end
end
