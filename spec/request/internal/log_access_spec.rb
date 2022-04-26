require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Internal Log Access Endpoint' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

  describe 'GET /internal/v4/log_access/:app_guid' do
    context 'permissions' do
      let(:api_call) { lambda { |user_headers| get "/internal/v4/log_access/#{app_model.guid}", nil, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200)
        %w[no_role global_auditor org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end
end
