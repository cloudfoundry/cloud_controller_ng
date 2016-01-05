require 'rails_helper'

describe ServiceBindingsController, type: :controller do
  describe '#create' do
    let(:membership) { instance_double(VCAP::CloudController::Membership) }
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
      { 'credentials' => {'super' => 'secret'},
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

      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(VCAP::CloudController::SecurityContext).to receive(:current_user)
        .and_return(current_user)
      allow(VCAP::CloudController::SecurityContext).to receive(:current_user_email)
        .and_return(current_user_email)
    end

    it 'returns a 201 Created and the service binding' do
      post :create, body: req_body

      service_binding = app_model.service_bindings.last

      expect(response.status).to eq 201
      expect(MultiJson.load(response.body)['guid']).to eq(service_binding.guid)
      expect(MultiJson.load(response.body)['type']).to eq(service_binding_type)
      expect(MultiJson.load(response.body)['data']['syslog_drain_url']).to eq('syslog://syslog-drain.com')
      expect(MultiJson.load(response.body)['data']['credentials']).to eq({'super'=>'secret'})
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
        expect(MultiJson.load(response.body)['guid']).to eq(service_binding.guid)
        expect(MultiJson.load(response.body)['type']).to eq(service_binding_type)
      end
    end

    context 'permissions' do
      context 'when the user is not a space developer of the requested space' do
        before do
          allow(membership).to receive(:has_any_roles?)
            .with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid)
            .and_return(false)
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
        expect(MultiJson.load(response.body)['guid']).to eq(service_binding.guid)
        expect(MultiJson.load(response.body)['type']).to eq(service_binding_type)
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
          allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance)
            .to receive(:bindable?).and_return(false)
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
end
