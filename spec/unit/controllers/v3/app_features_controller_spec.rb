require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppFeaturesController, type: :controller do
  let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
  let(:space) { app_model.space }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make }
  let(:app_feature_ssh_response) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => true } }

  before do
    space.update(allow_ssh: true)
    TestConfig.override(allow_app_ssh_access: true)
    set_current_user_as_role(role: 'admin', org: nil, space: nil, user: user)
  end

  describe '#index' do
    let(:pagination_hash) do
      {
        'total_results' => 1,
        'total_pages' => 1,
        'first' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'last' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'next' => nil,
        'previous' => nil,
      }
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) { READ_ONLY_PERMS }
        let(:api_call) { lambda { get :index, params: { app_guid: app_model.guid } } }
      end
    end

    it 'returns app features' do
      get :index, params: { app_guid: app_model.guid }
      expect(parsed_body).to eq(
        'resources' => [app_feature_ssh_response],
        'pagination' => pagination_hash
      )
    end

    it 'responds 404 when the app does not exist' do
      get :index, params: { app_guid: 'no-such-guid' }

      expect(response.status).to eq(404)
    end
  end

  describe '#show' do
    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_ONLY_PERMS }
      let(:api_call) { lambda { get :show, params: { app_guid: app_model.guid, name: 'ssh' } } }
    end

    it 'returns specific app feature' do
      get :show, params: { app_guid: app_model.guid, name: 'ssh' }
      expect(parsed_body).to eq(app_feature_ssh_response)
    end

    it 'throws 404 for a non-existent feature' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      get :show, params: { app_guid: app_model.guid, name: 'i-dont-exist' }

      expect(response.status).to eq(404)
      expect(response).to have_error_message('Feature not found')
    end

    it 'responds 404 when the app does not exist' do
      get :show, params: { app_guid: 'no-such-guid', name: 'ssh' }

      expect(response.status).to eq(404)
    end
  end

  describe '#update' do
    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_AND_WRITE_PERMS }
      let(:api_call) { lambda { patch :update, params: { app_guid: app_model.guid, name: 'ssh', enabled: false }, as: :json } }
    end

    it 'updates a given app feature' do
      expect(VCAP::CloudController::Permissions::Queryer).to receive(:new).and_call_original.exactly(:once)
      expect {
        patch :update, params: { app_guid: app_model.guid, name: 'ssh', enabled: false }, as: :json
      }.to change { app_model.reload.enable_ssh }.to(false)

      expect(response.status).to eq(200)
      expect(parsed_body['name']).to eq('ssh')
      expect(parsed_body['description']).to eq('Enable SSHing into the app.')
      expect(parsed_body['enabled']).to eq(false)
    end

    it 'responds 404 when the feature does not exist' do
      expect {
        patch :update, params: { app_guid: app_model.guid, name: 'no-such-feature', enabled: false }, as: :json
      }.not_to change { app_model.reload.values }

      expect(response.status).to eq(404)
    end

    it 'responds 404 when the app does not exist' do
      patch :update, params: { app_guid: 'no-such-guid', name: 'ssh', enabled: false }, as: :json

      expect(response.status).to eq(404)
    end

    it 'responds 422 when enabled param is missing' do
      expect {
        patch :update, params: { app_guid: app_model.guid, name: 'ssh' }, as: :json
      }.not_to change { app_model.reload.values }

      expect(response.status).to eq(422)
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
      let(:api_call) { lambda { get :ssh_enabled, params: { guid: app_model.guid } } }
    end

    it 'responds 404 when the app does not exist' do
      get :ssh_enabled, params: { guid: 'non-existent-app' }

      expect(response.status).to eq(404)
    end
  end
end
