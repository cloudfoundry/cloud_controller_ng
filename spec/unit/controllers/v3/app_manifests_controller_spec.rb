require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppManifestsController, type: :controller do
  describe '#show' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_yml_manifest) do
      {
        'applications' => [
          {
            'name' => app_model.name,
            'stack' => app_model.lifecycle_data.stack,
          }
        ]
      }.to_yaml
    end

    before do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)
    end

    it 'returns a 200' do
      get :show, params: { guid: app_model.guid }
      expect(response.status).to eq(200)
    end

    it 'returns a YAML manifest for the app' do
      get :show, params: { guid: app_model.guid }
      expect(response.body).to eq(expected_yml_manifest)
      expect(response.headers['Content-Type']).to eq('application/x-yaml; charset=utf-8')
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 200,
            'global_auditor' => 403,
            'space_developer' => 200,
            'space_manager' => 403,
            'space_auditor' => 403,
            'org_manager' => 403,
            'org_auditor' => 404,
            'org_billing_manager' => 404,
          }
        end
        let(:api_call) { lambda { get :show, params: { guid: app_model.guid } } }
      end
    end
  end
end
