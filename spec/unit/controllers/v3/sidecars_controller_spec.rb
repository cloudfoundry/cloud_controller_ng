require 'rails_helper'
require 'permissions_spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe SidecarsController, type: :controller do
  let!(:app_model) { VCAP::CloudController::AppModel.make(space:) }
  let(:user) { VCAP::CloudController::User.make }
  let!(:org) { VCAP::CloudController::Organization.make(name: "Lyle's Farm") }
  let!(:space) { VCAP::CloudController::Space.make(name: 'Cat', organization: org) }

  before do
    set_current_user(user)
  end

  describe 'index' do
    let!(:process1) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'web'
      )
    end

    context 'when not accessed as an app or process subresource' do
      before do
        set_current_user_as_role(role: :space_developer, org: org, user: user, space: space)
      end

      it 'fails to map a route' do
        expect do
          get :index_by_process
        end.to raise_error(ActionController::UrlGenerationError, /No route matches \{:action=>"index_by_process", :controller=>"sidecars"\}/)
      end
    end

    context 'when accessed as an app subresource' do
      before do
        set_current_user_as_role(role: :space_developer, org: org, user: user, space: space)
      end

      it 'succeeds' do
        get :index_by_app, params: { app_guid: app_model.guid }
        expect(response.status).to eq(200), response.body
      end
    end

    context 'permissions for index_by_process' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 200,
            'global_auditor' => 200,
            'space_developer' => 200,
            'space_manager' => 200,
            'space_auditor' => 200,
            'org_manager' => 200,
            'org_auditor' => 404,
            'org_billing_manager' => 404
          }
        end
        let(:api_call) { -> { get :index_by_process, params: { process_guid: process1.guid } } }
      end
    end

    context 'permissions for index_by_app' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 200,
            'global_auditor' => 200,
            'space_developer' => 200,
            'space_manager' => 200,
            'space_auditor' => 200,
            'org_manager' => 200,
            'org_auditor' => 404,
            'org_billing_manager' => 404
          }
        end
        let(:api_call) { -> { get :index_by_app, params: { app_guid: app_model.guid } } }
      end
    end
  end

  describe '#create' do
    before do
      set_current_user_as_role(role: :space_developer, org: org, user: user, space: space)
    end

    let(:sidecar_name) { 'sidecar_one' }
    let(:sidecar_params) do
      {
        guid: app_model.guid,
        name: sidecar_name,
        command: 'bundle exec rackup',
        process_types: %w[web other_worker]
      }
    end

    it 'creates a sidecar for a process' do
      expect do
        post :create, params: sidecar_params, as: :json
      end.to change(VCAP::CloudController::SidecarModel, :count).by(1)

      sidecar = VCAP::CloudController::SidecarModel.last

      expect(response).to have_http_status :created

      expected_response = {
        'guid' => sidecar.guid,
        'name' => 'sidecar_one',
        'command' => 'bundle exec rackup',
        'process_types' => %w[other_worker web],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'memory_in_mb' => nil,
        'origin' => 'user',
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        }
      }
      expect(parsed_body).to be_a_response_like(expected_response)
    end

    context 'when the user does not have read permissions on the app space' do
      before do
        disallow_user_read_access(user, space:)
      end

      it 'returns a 404 ResourceNotFound' do
        post :create, params: sidecar_params, as: :json

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 201,
        'space_developer' => 201,
        'global_auditor' => 403,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_manager' => 403,
        'admin_read_only' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
        'org_user' => 404
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:new_user) { VCAP::CloudController::User.make }

          before do
            set_current_user(new_user)
          end

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, user: new_user, space: space)

            post :create, params: sidecar_params, as: :json

            expect(response.status).to eq expected_return_value
          end
        end
      end
    end

    describe 'when attempting to create a sidecar with duplicate name' do
      let(:sidecar_name) { 'my_sidecar' }
      let!(:sidecar) { VCAP::CloudController::SidecarModel.make(name: 'my_sidecar', app: app_model) }

      it 'returns 422' do
        post :create, params: sidecar_params, as: :json
        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Sidecar with name \'my_sidecar\' already exists for given app'
      end
    end

    describe 'when app does not exist' do
      it 'returns 404' do
        sidecar_params[:guid] = '1234'
        post :create, params: sidecar_params, as: :json
        expect(response).to have_http_status :not_found
      end
    end
  end

  describe '#update' do
    let(:sidecar) { VCAP::CloudController::SidecarModel.make(app: app_model) }
    let(:sidecar_params) do
      {
        guid: sidecar.guid,
        name: 'my_sidecar',
        command: 'bundle exec rackup',
        process_types: %w[web other_worker]
      }
    end

    describe 'permissions by role' do
      let(:new_user) { VCAP::CloudController::User.make }

      role_to_expected_http_response = {
        'admin' => 200,
        'space_developer' => 200,
        'global_auditor' => 403,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_manager' => 403,
        'admin_read_only' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
        'org_user' => 404
      }

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          before do
            set_current_user(new_user)
          end

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, user: new_user, space: space)
            patch :update, params: sidecar_params, as: :json
            expect(response.status).to eq expected_return_value
          end
        end
      end
    end
  end

  describe '#show' do
    let(:sidecar) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar', command: 'smarch') }

    context 'the sidecar is not found' do
      it 'returns a 404' do
        get :show, params: { guid: 'nope' }, as: :json

        expect(response).to have_http_status :not_found
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 200,
          'space_developer' => 200,
          'global_auditor' => 200,
          'space_manager' => 200,
          'space_auditor' => 200,
          'org_manager' => 200,
          'admin_read_only' => 200,
          'org_auditor' => 404,
          'org_billing_manager' => 404
        }
      end
      let(:api_call) { -> { get :show, params: { guid: sidecar.guid }, as: :json } }
    end
  end

  describe '#delete' do
    let!(:sidecar) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar', command: 'smarch') }

    context 'as a space developer' do
      before do
        set_current_user_as_role(role: :space_developer, org: org, user: user, space: space)
      end

      it 'deletes the sidecar' do
        expect do
          delete :destroy, params: { guid: sidecar.guid }, as: :json
        end.to change(VCAP::CloudController::SidecarModel, :count).by(-1)
      end

      context 'the sidecar is not found' do
        it 'returns a 404' do
          delete :destroy, params: { guid: 'nope' }, as: :json

          expect(response).to have_http_status :not_found
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 204,
          'space_developer' => 204,
          'global_auditor' => 403,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'admin_read_only' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404
        }
      end
      let(:api_call) { -> { delete :destroy, params: { guid: sidecar.guid }, as: :json } }
    end
  end
end
