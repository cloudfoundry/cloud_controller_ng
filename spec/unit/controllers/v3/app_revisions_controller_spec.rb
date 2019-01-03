require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppRevisionsController, type: :controller do
  describe '#revision' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808) }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 and shows the revision' do
      get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

      expect(response.status).to eq(200)
      expect(parsed_body).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
            }
          }
        }
      )
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :show, params: { guid: 'hahaha', revision_guid: revision.guid }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'raises an ApiError with a 404 code when the revision does not exist' do
      get :show, params: { guid: app_model.guid, revision_guid: 'hahaha' }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'raises an ApiError with a 404 code when the revision belongs to a different app' do
      other_app = VCAP::CloudController::AppModel.make

      get :show, params: { guid: other_app.guid, revision_guid: revision.guid }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end

  describe '#revisions' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:app_without_revisions) { VCAP::CloudController::AppModel.make(space: space) }
    let!(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }
    let!(:revision1) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808) }
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 809) }
    let!(:revision_for_another_app) { VCAP::CloudController::RevisionModel.make }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 and shows the revisions' do
      get :index, params: { guid: app_model.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['resources'].map { |r| r['guid'] }).to contain_exactly(revision1.guid, revision2.guid)
    end

    context 'filters' do
      let!(:revision3) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 810) }

      it 'by version' do
        get :index, params: { guid: app_model.guid, versions: '808,810' }

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['guid'] }).to contain_exactly(revision1.guid, revision3.guid)
      end
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :index, params: { guid: 'hahaha' }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'returns an empty array when the app has no revisions' do
      get :index, params: { guid: app_without_revisions.guid }

      expect(response.status).to eq 200
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
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :index, params: { guid: app_model.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end
end
