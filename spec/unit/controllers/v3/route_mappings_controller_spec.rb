require 'rails_helper'

RSpec.describe RouteMappingsController, type: :controller do
  let(:app) { VCAP::CloudController::AppModel.make }
  let(:space) { app.space }
  let(:org) { space.organization }
  let!(:app_process) { VCAP::CloudController::ProcessModel.make(:process, app: app, type: 'web', ports: [8080]) }
  let(:route) { VCAP::CloudController::Route.make(space: space) }
  let(:process_type) { 'web' }

  describe '#create' do
    let(:req_body) do
      {
        relationships: {
          app:     { guid: app.guid },
          route:   { guid: route.guid },
          process: { type: process_type }
        }
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'successfully creates a route mapping' do
      post :create, body: req_body

      expect(response.status).to eq(201)
      expect(parsed_body['guid']).to eq(VCAP::CloudController::RouteMappingModel.last.guid)
    end

    context 'when there is a validation error' do
      let(:process_type) { true }

      it 'raises an unprocessable error' do
        post :create, body: req_body

        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the requested route does not exist' do
      let(:req_body) do
        {
          relationships: {
            route: { guid: 'bad-route-guid' },
            app:   { guid: app.guid }
          }
        }
      end

      it 'raises an API 404 error' do
        post :create, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Route not found')
      end
    end

    context 'when the requested app does not exist' do
      let(:req_body) do
        {
          relationships: {
            route: { guid: route.guid },
            app:   { guid: 'bad-guid' }
          }
        }
      end

      it 'raises an API 404 error' do
        post :create, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the mapping is invalid' do
      before do
        allow(VCAP::CloudController::RouteMappingCreate).to receive(:add).and_raise(VCAP::CloudController::RouteMappingCreate::InvalidRouteMapping.new('shablam'))
      end

      it 'returns an UnprocessableEntity error' do
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'permissions' do
      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          post :create, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user does not have read access to the space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          post :create, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          post :create, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#update' do
    let(:original_weight) { 3 }
    let(:updated_weight) { original_weight + 10 }
    let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route, weight: original_weight) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:req_body) do
      {
        weight: updated_weight
      }
    end

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'updates the route mapping weight' do
      patch :update, body: req_body, route_mapping_guid: route_mapping.guid
      expect(response.status).to eq(201)
      expect(parsed_body['guid']).to eq(route_mapping.guid)
      expect(parsed_body['weight']).to eq(updated_weight)
      expect(route_mapping.reload.weight).to eq(updated_weight)
    end

    context 'when there is a validation error' do
      let(:updated_weight) { 'infinity' }

      it 'raises an unprocessable error' do
        patch :update, body: req_body, route_mapping_guid: route_mapping.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when there is no weight in the patch' do
      let(:req_body) do
        {}
      end

      it 'does not change the weight' do
        patch :update, body: req_body, route_mapping_guid: route_mapping.guid
        expect(response.status).to eq(201)
        expect(route_mapping.reload.weight).to eq(original_weight)
      end
    end

    context 'when copilot is enabled' do
      before do
        TestConfig.override(copilot: { enabled: true })
        allow(VCAP::CloudController::Copilot::Adapter).to receive(:map_route)
      end

      it 'delegates to the copilot handler to notify copilot' do
        patch :update, body: req_body, route_mapping_guid: route_mapping.guid
        expect(route_mapping.reload.weight).to eq(updated_weight)
        expect(VCAP::CloudController::Copilot::Adapter).to have_received(:map_route).with(route_mapping)
      end

      context 'when VCAP::CloudController::Copilot::Adapter#map_route errors out' do
        let(:event_repository) { double(Repositories::AppEventRepository) }
        let(:logger) { instance_double(Steno::Logger, error: nil) }

        before do
          allow(VCAP::CloudController::Copilot::Adapter).to receive(:map_route).and_raise(VCAP::CloudController::Copilot::Adapter::CopilotUnavailable.new('some-error'))
          allow(logger).to receive(:error)
          allow(Steno).to receive(:logger).and_return(logger)
        end

        it 'logs and swallows the error' do
          patch :update, body: req_body, route_mapping_guid: route_mapping.guid
          expect(VCAP::CloudController::Copilot::Adapter).to have_received(:map_route).with(route_mapping)
          expect(logger).to have_received(:error).with('failed communicating with copilot backend: some-error')
          expect(route_mapping.reload.weight).to eq(updated_weight)
          expect(response.status).to eq(201)
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'raises 403' do
          patch :update, body: req_body, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          patch :update, body: req_body, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Route mapping not found'
        end
      end

      context 'when the user can read but cannot write to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          patch :update, body: req_body, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#show' do
    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'successfully get a route mapping' do
      get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(VCAP::CloudController::RouteMappingModel.last.guid)
    end

    it 'returns a 404 if the route mapping does not exist' do
      get :show, app_guid: app.guid, route_mapping_guid: 'fake-guid'

      expect(response.status).to eq(404)
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'Route mapping not found'
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'raises 403' do
          get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          get :show, app_guid: app.guid, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Route mapping not found'
        end
      end
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'returns route mappings the user has roles to see' do
      route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app: VCAP::CloudController::AppModel.make(space: space))
      route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app: VCAP::CloudController::AppModel.make(space: space))
      VCAP::CloudController::RouteMappingModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([route_mapping_1.guid, route_mapping_2.guid])
    end

    it 'provides the correct base url in the pagination links' do
      get :index
      expect(parsed_body['pagination']['first']['href']).to include('/v3/route_mappings')
    end

    context 'when accessed as an app subresource' do
      it 'uses the app as a filter' do
        route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app: app)
        route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app: app)
        VCAP::CloudController::RouteMappingModel.make(app: VCAP::CloudController::AppModel.make(space: space))

        get :index, app_guid: app.guid

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([route_mapping_1.guid, route_mapping_2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app.guid
        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app.guid}/route_mappings")
      end

      context 'when pagination options are specified' do
        let(:page) { 1 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page } }

        it 'paginates the response' do
          VCAP::CloudController::RouteMappingModel.make(app: app)
          VCAP::CloudController::RouteMappingModel.make(app: app)

          get :index, params

          parsed_response = parsed_body
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(response_guids.length).to eq(per_page)
        end
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, app_guid: 'hello-i-do-not-exist'

          expect(response.status).to eq 404
          expect(response.body).to include 'App'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: app.guid

          expect(response.body).to include 'App'
          expect(response.status).to eq 404
        end
      end

      context 'when the user can read, but not write to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200' do
          get :index, app_guid: app.guid
          expect(response.status).to eq 200
        end
      end
    end

    context 'permissions' do
      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        it 'lists all route_mappings' do
          route_mapping_1 = VCAP::CloudController::RouteMappingModel.make(app_guid: app.guid)
          route_mapping_2 = VCAP::CloudController::RouteMappingModel.make(app_guid: app.guid)
          route_mapping_3 = VCAP::CloudController::RouteMappingModel.make

          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids).to match_array([route_mapping_1.guid, route_mapping_2.guid, route_mapping_3.guid])
        end
      end

      context 'when the user does not have read scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#destroy' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route) }

    it 'successfully deletes the specified route mapping' do
      delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

      expect(response.status).to eq 204
      expect(route_mapping.exists?).to be_falsey
    end

    context 'when the route mapping does not exist' do
      it 'raises an API 404 error' do
        delete :destroy, app_guid: app.guid, route_mapping_guid: 'not-real'

        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Route mapping not found'
        expect(response.status).to eq 404
      end
    end

    context 'permissions' do
      context 'when the user can read, but not write to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises an API 403 error' do
          delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          delete :destroy, app_guid: app.guid, route_mapping_guid: route_mapping.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end
end
