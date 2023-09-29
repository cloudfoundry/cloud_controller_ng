require 'rails_helper'
require 'permissions_spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe AppRevisionsController, type: :controller do
  let!(:space) { app_model.space }
  let(:user) { VCAP::CloudController::User.make }

  before do
    set_current_user(user)
    allow_user_read_access_for(user, spaces: [space])
    allow_user_secret_access(user, space:)
  end

  describe '#index' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:app_without_revisions) { VCAP::CloudController::AppModel.make(space:) }
    let!(:revision1) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808) }
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 809) }
    let!(:revision_for_another_app) { VCAP::CloudController::RevisionModel.make }

    it 'returns 200 and shows the revisions' do
      get :index, params: { guid: app_model.guid }

      expect(response).to have_http_status(:ok)
      expect(parsed_body['resources'].pluck('guid')).to contain_exactly(revision1.guid, revision2.guid)
    end

    context 'filters' do
      let!(:revision3) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 810) }

      it 'by version' do
        get :index, params: { guid: app_model.guid, versions: '808,810' }

        expect(response).to have_http_status(:ok)
        expect(parsed_body['resources'].pluck('guid')).to contain_exactly(revision1.guid, revision3.guid)
      end
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :index, params: { guid: 'hahaha' }

      expect(response).to have_http_status :not_found
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'returns an empty array when the app has no revisions' do
      get :index, params: { guid: app_without_revisions.guid }

      expect(response).to have_http_status :ok
      expect(parsed_body['resources']).to be_empty
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :index, params: { guid: app_model.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response).to have_http_status :forbidden
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :index, params: { guid: app_model.guid }

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end

  describe '#deployed' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:app_without_revisions) { VCAP::CloudController::AppModel.make(space:) }
    let!(:revision1) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808) }
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 809) }
    let!(:revision_for_another_app) { VCAP::CloudController::RevisionModel.make }
    let!(:revision3) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 810) }
    let!(:process1) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision1, type: 'web', state: 'STARTED') }
    let!(:process2) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision2, type: 'worker', state: 'STARTED') }
    let!(:process3) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision3, type: 'web', state: 'STOPPED') }

    it 'returns the deployed revisions' do
      get :deployed, params: { guid: app_model.guid }

      expect(response).to have_http_status(:ok)
      expect(parsed_body['resources'].pluck('guid')).to contain_exactly(revision1.guid, revision2.guid)
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :deployed, params: { guid: 'hahaha' }

      expect(response).to have_http_status :not_found
      expect(response.body).to include 'ResourceNotFound'
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :deployed, params: { guid: app_model.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response).to have_http_status :forbidden
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :deployed, params: { guid: app_model.guid }

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end
end
