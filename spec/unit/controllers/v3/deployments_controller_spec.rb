require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe DeploymentsController, type: :controller do
  let(:user) { VCAP::CloudController::User.make }
  let(:app) { VCAP::CloudController::AppModel.make(droplet: droplet) }
  let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app) }
  let(:droplet) { VCAP::CloudController::DropletModel.make }
  let(:app_guid) { app.guid }
  let(:space) { app.space }
  let(:org) { space.organization }

  describe '#create' do
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

      it 'returns a 201' do
        post :create, body: req_body

        expect(response.status).to eq(201)
      end

      it 'creates a deployment' do
        expect(VCAP::CloudController::DeploymentCreate).
          to receive(:create).
          with(app: app, user_audit_info: instance_of(VCAP::CloudController::UserAuditInfo)).
          and_call_original

        post :create, body: req_body
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
      }}
      let(:api_call) { lambda { post :create, body: req_body } }
    end

    context 'when the user does not have permission' do
      before do
        set_current_user(user, scopes: %w(cloud_controller.write))
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

  describe '#show' do
    let(:deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app, droplet: droplet) }

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      end

      it 'returns a 200 on show existing deployment' do
        get :show, guid: deployment.guid

        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(deployment.guid)
      end

      it 'returns a 404 on bogus deployment' do
        get :show, guid: 'not a deployment'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end

      context 'when the current droplet changes on the app' do
        let(:new_droplet) { VCAP::CloudController::DropletModel.make }

        it 'shows the droplet guid for the droplet the deployment was created with' do
          app.update(droplet: new_droplet)

          get :show, guid: deployment.guid

          expect(response.status).to eq(200)
          expect(parsed_body['guid']).to eq(deployment.guid)
          expect(parsed_body['relationships']['app']['data']['guid']).to eq(app.guid)
          expect(parsed_body['droplet']['guid']).to eq(droplet.guid)
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { {
        'admin' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'space_developer' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
      }}
      let(:api_call) { lambda { get :show, guid: deployment.guid } }
    end

    it 'returns 401 for Unauthenticated requests' do
      get :show, guid: deployment.guid
      expect(response.status).to eq(401)
    end
  end

  describe '#index' do
    let!(:deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app) }
    let!(:another_deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app) }

    context 'permissions' do
      describe 'authorization' do
        role_to_expected_http_response = {
          'admin' => 200,
          'admin_read_only' => 200,
          'global_auditor' => 200,
          'space_developer' => 200,
          'space_manager' => 200,
          'space_auditor' => 200,
          'org_manager' => 200,
          'org_auditor' => 200,
          'org_billing_manager' => 200,
        }.freeze

        has_no_space_access = {
          'org_auditor' => true,
          'org_billing_manager' => true,
        }

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              get :index
              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
              resources = parsed_body['resources']
              if has_no_space_access[role]
                expect(resources.size).to eq(0), "role #{role}: expected 0, got: #{resources.size}"
              else
                expect(resources.size).to eq(2), "role #{role}: expected 2, got: #{resources.size}"
                expect(resources.map { |r| r['guid'] }).to match_array([deployment.guid, another_deployment.guid])
              end
            end
          end
        end
      end

      context 'when the user does not have the "cloud_controller.read" scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'returns a 403 Not Authorized error' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end

    describe 'request validity and pagination' do
      before do
        set_current_user_as_admin(user: user)
      end

      context 'query params' do
        context 'invalid param format' do
          let(:params) { { 'order_by' => '^%' } }

          it 'returns 400' do
            get :index, params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
          end
        end

        context 'unknown query param' do
          let(:params) { { 'bad_param' => 'foo' } }

          it 'returns 400' do
            get :index, params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include('Unknown query parameter(s)')
            expect(response.body).to include('bad_param')
          end
        end

        context 'invalid pagination' do
          let(:params) { { 'per_page' => 9999999999999999 } }

          it 'returns 400' do
            get :index, params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include('Per page must be between')
          end
        end

        context 'query params in pagination links' do
          let(:params) { { 'per_page' => 1 } }

          it 'adds requested params to the links' do
            get :index, params

            expect(response.status).to eq(200)
            expect(parsed_body['pagination']['next']['href']).to start_with("#{link_prefix}/v3/deployments")
            expect(parsed_body['pagination']['next']['href']).to match(/per_page=1/)
            expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
          end
        end
      end
    end
  end
end
