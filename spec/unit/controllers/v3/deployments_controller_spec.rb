require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe DeploymentsController, type: :controller do
  describe '#create' do
    let(:user) { VCAP::CloudController::User.make }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:app_guid) { app.guid }
    let(:space) { app.space }
    let(:org) { space.organization }
    let(:req_body) do
      {
        relationships: {
          app: {
            data: {
              guid: app_guid
            }
          }
        },
      }
    end

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      end

      it 'returns a 201 on create with authorized use' do
        post :create, body: req_body

        expect(response.status).to eq(201)
      end

      context 'when the app does not exist' do
        let(:app_guid) { 'does-not-exist' }

        it 'returns 422 with an error message' do
          post :create, body: req_body
          expect(response.status).to eq 422
          expect(response.body).to include('Unable to use app. Ensure that the app exists and you have access to it.')
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { {
        'admin' => 201,
        'admin_read_only' => 422,
        'global_auditor' => 422,
        'space_developer' => 201,
        'space_manager' => 422,
        'space_auditor' => 422,
        'org_manager' => 422,
        'org_auditor' => 422,
        'org_billing_manager' => 422,
      } }
      let(:api_call) { lambda { post :create, body: req_body } }
    end

    context 'when the user does not have permission' do
      before do
        set_current_user(user, admin_read_only: true)
      end

      it 'returns 422 with an error message' do
        post :create, body: req_body
        expect(response.status).to eq 422
        expect(response.body).to include('Unable to use app. Ensure that the app exists and you have access to it.')
      end
    end

    it 'returns 401 for Unauthenticated requests' do
      post :create, body: req_body
      expect(response.status).to eq(401)
    end
  end
end
