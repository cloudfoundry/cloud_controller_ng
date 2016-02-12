require 'rails_helper'
require 'actions/service_binding_create'

describe ServiceBindingsController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  before do
    @request.env.merge!(headers_for(VCAP::CloudController::User.make))
    allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
    allow(membership).to receive(:has_any_roles?).and_return(true)
  end

  describe '#create' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org_guid) { space.organization.guid }
    let(:service_binding_type) { 'app' }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, syslog_drain_url: 'syslog://syslog-drain.com') }
    let(:req_body) do
      {
        type: service_binding_type,
        relationships:
        {
          app: { guid: app_model.guid },
          service_instance: { guid: service_instance.guid }
        }
      }
    end
    let(:current_user) { double(:current_user, guid: 'some-guid') }
    let(:current_user_email) { 'are@youreddy.com' }
    let(:body) do
      { 'credentials' => { 'super' => 'secret' },
        'syslog_drain_url' => 'syslog://syslog-drain.com'
      }.to_json
    end
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }
    let(:fake_service_binding) { VCAP::CloudController::ServiceBindingModel.new(service_instance: service_instance, guid: '') }
    let(:opts) do
      {
        fake_service_binding: fake_service_binding,
        body: body
      }
    end

    before do
      stub_bind(service_instance, opts)
      service_instance.service.requires = ['syslog_drain']
      service_instance.service.save

      allow(VCAP::CloudController::SecurityContext).to receive(:current_user).
        and_return(current_user)
      allow(VCAP::CloudController::SecurityContext).to receive(:current_user_email).
        and_return(current_user_email)
    end

    it 'returns a 201 Created and the service binding' do
      post :create, body: req_body

      service_binding = app_model.service_bindings.last

      expect(response.status).to eq 201
      expect(parsed_body['guid']).to eq(service_binding.guid)
      expect(parsed_body['type']).to eq(service_binding_type)
      expect(parsed_body['data']['syslog_drain_url']).to eq('syslog://syslog-drain.com')
      expect(parsed_body['data']['credentials']).to eq({ 'super' => 'secret' })
    end

    describe 'arbitrary parameters' do
      let(:req_body) do
        {
          type: service_binding_type,
          relationships: {
            app: { guid: app_model.guid },
            service_instance: { guid: service_instance.guid }
          },
          data: {
            parameters: { 'arbi' => 'trary', 'par' => 'ameters' }
          }
        }
      end

      it 'passes them to ServiceBindingCreate' do
        service_binding_create = VCAP::CloudController::ServiceBindingCreate.new
        allow(service_binding_create).to receive(:create).and_call_original
        allow(VCAP::CloudController::ServiceBindingCreate).to receive(:new).and_return service_binding_create

        post :create, body: req_body

        expect(service_binding_create).to have_received(:create) do |_, _, _, arbitrary_parameters|
          expect(arbitrary_parameters).to eq('arbi' => 'trary', 'par' => 'ameters')
        end
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 201 and the service binding' do
        post :create, body: req_body

        service_binding = app_model.service_bindings.last

        expect(response.status).to eq 201
        expect(parsed_body['guid']).to eq(service_binding.guid)
        expect(parsed_body['type']).to eq(service_binding_type)
      end
    end

    context 'permissions' do
      context 'when the user is not a space developer of the requested space' do
        before do
          allow(membership).to receive(:has_any_roles?).
            with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'returns a 403 Not Authorized' do
          post :create, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the request is missing required fields' do
      let(:req_body) do
        {
          relationships:
          {
            app: { guid: app_model.guid },
            service_instance: { guid: service_instance.guid }
          }
        }
      end

      it 'raises a 422 UnprocessableEntity' do
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the type is invalid' do
      let(:req_body) do
        {
          type: 1234,
          relationships:
          {
            app: { guid: app_model.guid },
            service_instance: { guid: service_instance.guid }
          }
        }
      end

      it 'raises a 422 UnprocessableEntity' do
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the request includes unrecognized fields' do
      let(:req_body) do
        {
          type: 'app',
          relationships:
          {
            app: { guid: app_model.guid },
            service_instance: { guid: service_instance.guid }
          },
          potato: 'tomato'
        }
      end

      it 'raises a 422 UnprocessableEntity' do
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the app does not exist' do
      let(:req_body) do
        {
          type: service_binding_type,
          relationships:
          {
            app: { guid: 'schmuid' },
            service_instance: { guid: service_instance.guid }
          }
        }
      end

      it 'raises an 404 ResourceNotFound error' do
        post :create, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the service instance does not exist' do
      let(:req_body) do
        {
          type: service_binding_type,
          relationships:
          {
            app: { guid: app_model.guid },
            service_instance: { guid: 'schmuid' }
          }
        }
      end

      it 'raises an 404 ResourceNotFound error' do
        post :create, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Service instance not found'
      end
    end

    context 'when the request includes arbitrary parameter fields' do
      let(:req_body) do
        {
          type: 'app',
          relationships:
          {
            app: { guid: app_model.guid },
            service_instance: { guid: service_instance.guid }
          },
          data: {
            parameters: {
              banana: 'bread'
            }
          }
        }
      end

      it 'returns a 201 Created and the service binding' do
        post :create, body: req_body

        service_binding = app_model.service_bindings.last

        expect(response.status).to eq 201
        expect(parsed_body['guid']).to eq(service_binding.guid)
        expect(parsed_body['type']).to eq(service_binding_type)
      end

      context 'when data includes unauthorized keys' do
        let(:req_body) do
          {
            type: 'app',
            relationships:
            {
              app: { guid: app_model.guid },
              service_instance: { guid: service_instance.guid }
            },
            data: {
              sparameters: {
                banana: 'bread'
              }
            }
          }
        end

        it 'raises a 422 UnprocessableEntity' do
          post :create, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
        end
      end
    end

    context 'binding errors' do
      before do
        stub_request(:delete, service_binding_url_pattern)
      end

      context 'when attempting to bind an unbindable service' do
        before do
          allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance).
            to receive(:bindable?).and_return(false)
        end

        it 'raises an UnbindableService 400 error' do
          post :create, body: req_body

          expect(response.status).to eq 400
          expect(response.body).to include 'UnbindableService'
        end
      end

      context 'when the instance operation is in progress' do
        before do
          VCAP::CloudController::ServiceInstanceOperation.make(
            service_instance_id: service_instance.id,
            state: 'in progress')
        end

        it 'raises an AsyncServiceInstanceOperationInProgress 409 error' do
          post :create, body: req_body

          expect(response.status).to eq 409
          expect(response.body).to include 'AsyncServiceInstanceOperationInProgress'
        end
      end

      context 'when attempting to bind and the service binding already exists' do
        before do
          VCAP::CloudController::ServiceBindingModel.make(
            service_instance: service_instance,
            app: app_model
          )
        end

        it 'returns a ServiceBindingAppServiceTaken error' do
          post :create, body: req_body

          expect(response.status).to eq(400)
          expect(response.body).to include 'ServiceBindingAppServiceTaken'
        end
      end
    end
  end

  describe 'show' do
    let(:service_binding) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com') }
    let(:space) { service_binding.space }

    it 'returns a 200 OK and the service binding' do
      get :show, guid: service_binding.guid

      expect(response.status).to eq 200
      expect(parsed_body['guid']).to eq(service_binding.guid)
      expect(parsed_body['type']).to eq(service_binding.type)
      expect(parsed_body['data']['syslog_drain_url']).to eq('syslog://syslog-drain.com')
      expect(parsed_body['data']['credentials']).to eq(service_binding.credentials)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 OK and the service binding' do
        get :show, guid: service_binding.guid

        expect(response.status).to eq 200
        expect(parsed_body['guid']).to eq(service_binding.guid)
        expect(parsed_body['type']).to eq(service_binding.type)
        expect(parsed_body['data']['syslog_drain_url']).to eq('syslog://syslog-drain.com')
        expect(parsed_body['data']['credentials']).to eq(service_binding.credentials)
      end
    end

    context 'permissions' do
      context 'when the user has read-only permissions' do
        before do
          allow(membership).to receive(:has_any_roles?).
            with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'returns a 200' do
          get :show, guid: service_binding.guid

          expect(response.status).to eq 200
        end
      end

      context 'when the user does not have read scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
        end

        it 'returns a 403 NotAuthorized error' do
          get :show, guid: service_binding.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the does not have read permissions' do
        before do
          allow(membership).to receive(:has_any_roles?).
            and_return(false)
        end

        it 'returns a 404' do
          get :show, guid: service_binding.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Service binding not found'
        end
      end

      context 'when the service binding does not exist' do
        it 'raises an 404 ResourceNotFound error' do
          get :show, guid: 'schmuid'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Service binding not found'
        end
      end
    end
  end

  describe 'index' do
    let!(:allowed_binding_1) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com') }
    let!(:allowed_binding_2) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com', service_instance: service_instance) }
    let!(:allowed_binding_3) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com', service_instance: service_instance) }
    let!(:binding_in_unauthorized_space) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com') }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: allowed_space) }
    let(:allowed_space) { allowed_binding_1.space }
    let(:unauthorized_space) { binding_in_unauthorized_space.space }

    before do
      allow(membership).to receive(:space_guids_for_roles).
        with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER]
        ).and_return(allowed_space.guid)
    end

    it 'returns a 200 and all service bindings the user is allowed to see' do
      get :index

      expect(response.status).to eq 200
      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([allowed_binding_1, allowed_binding_2, allowed_binding_3].map(&:guid))
    end

    context 'admin' do
      let(:expected_service_binding_guids) do
        [allowed_binding_1, allowed_binding_2, allowed_binding_3, binding_in_unauthorized_space].map(&:guid)
      end
      before do
        @request.env.merge!(admin_headers)
      end

      it 'returns all service bindings' do
        get :index

        expect(response.status).to eq 200
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array(expected_service_binding_guids)
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params

        parsed_response = parsed_body
        response_guids = parsed_response['resources'].map { |r| r['guid'] }
        expect(parsed_response['pagination']['total_results']).to eq(3)
        expect(response_guids.length).to eq(per_page)
      end
    end

    context 'when the user does not have the read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'returns a 403 NotAuthorized error' do
        get :index

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when parameters are invalid' do
      context 'because there are unknown parameters' do
        let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include("Unknown query parameter(s): 'invalid', 'bad'")
        end
      end

      context 'because there are invalid values in parameters' do
        let(:params) { { 'per_page' => 9999999999 } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between')
        end
      end
    end
  end

  describe 'destroy' do
    let(:service_binding) { VCAP::CloudController::ServiceBindingModel.make(syslog_drain_url: 'syslog://syslog-drain.com') }
    let(:space) { service_binding.space }

    before do
      stub_unbind(service_binding)
    end

    it 'returns a 204' do
      delete :destroy, guid: service_binding.guid
      expect(response.status).to eq 204
      expect(service_binding.exists?).to be_falsey
    end

    context 'permissions' do
      context 'admin with no other roles' do
        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 204 and deletes the service binding' do
          delete :destroy, guid: service_binding.guid
          expect(response.status).to eq 204
          expect(service_binding.exists?).to be_falsey
        end
      end

      context 'when the service binding does not exist' do
        it 'returns a 404' do
          delete :destroy, guid: 'fake-guid'

          expect(response.status).to eq 404
        end
      end

      context 'when the user has read-only permissions' do
        before do
          allow(membership).to receive(:has_any_roles?).
            with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'returns a 403 Not Authorized and does NOT delete the binding' do
          delete :destroy, guid: service_binding.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
          expect(service_binding.exists?).to be_truthy
        end
      end

      context 'when the user does not have the write scope' do
        before do
          @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
        end

        it 'returns a 403 NotAuthorized error and does NOT delete the binding' do
          delete :destroy, guid: service_binding.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
          expect(service_binding.exists?).to be_truthy
        end
      end

      context 'when the user does not have read permissions' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 404 and does NOT delete the binding' do
          delete :destroy, guid: service_binding.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Service binding not found'
          expect(service_binding.exists?).to be_truthy
        end
      end
    end
  end
end
