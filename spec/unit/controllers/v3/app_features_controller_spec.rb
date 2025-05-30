require 'rails_helper'
require 'permissions_spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe AppFeaturesController, type: :controller do
  let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true, service_binding_k8s_enabled: true) }
  let(:space) { app_model.space }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make }
  let(:app_feature_ssh_response) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => true } }
  let(:app_feature_revisions_response) { { 'name' => 'revisions', 'description' => 'Enable versioning of an application', 'enabled' => true } }
  let(:app_feature_service_binding_k8s_response) do
    { 'name' => 'service-binding-k8s', 'description' => 'Enable k8s service bindings for the app', 'enabled' => true }
  end
  let(:app_feature_file_based_vcap_services_response) do
    { 'name' => 'file-based-vcap-services', 'description' => 'Enable file-based VCAP service bindings for the app', 'enabled' => false }
  end

  before do
    space.update(allow_ssh: true)
    TestConfig.override(allow_app_ssh_access: true)
    set_current_user_as_role(role: 'admin', org: nil, space: nil, user: user)
  end

  describe '#index' do
    let(:pagination_hash) do
      {
        'total_results' => 4,
        'total_pages' => 1,
        'first' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'last' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'next' => nil,
        'previous' => nil
      }
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) { READ_ONLY_PERMS }
        let(:api_call) { -> { get :index, params: { app_guid: app_model.guid } } }
      end
    end

    it 'returns app features' do
      get :index, params: { app_guid: app_model.guid }
      expect(parsed_body).to eq(
        'resources' => [app_feature_ssh_response, app_feature_revisions_response, app_feature_service_binding_k8s_response, app_feature_file_based_vcap_services_response],
        'pagination' => pagination_hash
      )
    end

    it 'responds 404 when the app does not exist' do
      get :index, params: { app_guid: 'no-such-guid' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#show' do
    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_ONLY_PERMS }
      let(:api_call) { -> { get :show, params: { app_guid: app_model.guid, name: 'ssh' } } }
    end

    it 'returns the ssh app feature' do
      get :show, params: { app_guid: app_model.guid, name: 'ssh' }
      expect(parsed_body).to eq(app_feature_ssh_response)
    end

    it 'returns the revisions app feature' do
      get :show, params: { app_guid: app_model.guid, name: 'revisions' }
      expect(parsed_body).to eq(app_feature_revisions_response)
    end

    it 'returns the service-binding-k8s app feature' do
      get :show, params: { app_guid: app_model.guid, name: 'service-binding-k8s' }
      expect(parsed_body).to eq(app_feature_service_binding_k8s_response)
    end

    it 'returns the file-based-vcap-services feature' do
      get :show, params: { app_guid: app_model.guid, name: 'file-based-vcap-services' }
      expect(parsed_body).to eq(app_feature_file_based_vcap_services_response)
    end

    it 'throws 404 for a non-existent feature' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      get :show, params: { app_guid: app_model.guid, name: 'i-dont-exist' }

      expect(response).to have_http_status(:not_found)
      expect(response).to have_error_message('Feature not found')
    end

    it 'responds 404 when the app does not exist' do
      get :show, params: { app_guid: 'no-such-guid', name: 'ssh' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#update' do
    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_AND_WRITE_PERMS }
      let(:api_call) { -> { patch :update, params: { app_guid: app_model.guid, name: 'ssh', enabled: false }, as: :json } }
    end

    context 'updating ssh to false' do
      it 'disables ssh for the app' do
        expect(VCAP::CloudController::Permissions).to receive(:new).and_call_original.exactly(:once)
        patch :update, params: { app_guid: app_model.guid, name: 'ssh', enabled: false }, as: :json

        expect(response).to have_http_status(:ok)
        expect(parsed_body['name']).to eq('ssh')
        expect(parsed_body['description']).to eq('Enable SSHing into the app.')
        expect(parsed_body['enabled']).to be(false)
      end
    end

    context 'updating revisions to true' do
      it 'enables revisions for the app' do
        expect(VCAP::CloudController::Permissions).to receive(:new).and_call_original.exactly(:once)
        patch :update, params: { app_guid: app_model.guid, name: 'revisions', enabled: false }, as: :json

        expect(response).to have_http_status(:ok)
        expect(parsed_body['name']).to eq('revisions')
        expect(parsed_body['description']).to eq('Enable versioning of an application')
        expect(parsed_body['enabled']).to be(false)
      end
    end

    it 'responds 404 when the feature does not exist' do
      expect do
        patch :update, params: { app_guid: app_model.guid, name: 'no-such-feature', enabled: false }, as: :json
      end.not_to(change { app_model.reload.values })

      expect(response).to have_http_status(:not_found)
    end

    it 'responds 404 when the app does not exist' do
      patch :update, params: { app_guid: 'no-such-guid', name: 'ssh', enabled: false }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'responds 422 when enabled param is missing' do
      expect do
        patch :update, params: { app_guid: app_model.guid, name: 'ssh' }, as: :json
      end.not_to(change { app_model.reload.values })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to have_error_message('Enabled must be a boolean')
    end
  end

  describe '#ssh_enabled' do
    let(:ssh_enabled) do
      {
        'enabled' => true,
        'reason' => ''
      }
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_ONLY_PERMS }
      let(:api_call) { -> { get :ssh_enabled, params: { guid: app_model.guid } } }
    end

    it 'responds 404 when the app does not exist' do
      get :ssh_enabled, params: { guid: 'non-existent-app' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
