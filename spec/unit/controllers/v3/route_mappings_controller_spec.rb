require 'rails_helper'

describe RouteMappingsController, type: :controller do
  let(:app) { VCAP::CloudController::AppModel.make }
  let(:space) { app.space }
  let(:org) { space.organization }
  let!(:app_process) { VCAP::CloudController::App.make(:process, app_guid: app.guid, type: 'web', space_guid: space.guid, ports: [8888]) }
  let(:route) { VCAP::CloudController::Route.make(space: space) }
  let(:process_type) { 'web' }

  describe '#create' do
    let(:req_body) do
      {
        app_port: 8888,
        relationships: {
          app:     { guid: app.guid },
          route:   { guid: route.guid },
          process: { type: process_type }
        }
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
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

    context 'when creating route mappings to the same process' do
      let(:req_body_2) do
        {
          app_port: 1024,
          relationships: {
            app:     { guid: app.guid },
            route:   { guid: route.guid },
            process: { type: process_type }
          }
        }
      end

      before do
        app_process.ports = [8888, 1024]
        app_process.save

        post :create, body: req_body
        expect(response.status).to eq 201
      end

      context 'when the ports are unique' do
        it 'succeeds' do
          post :create, body: req_body_2
          expect(response.status).to eq 201
        end
      end

      context 'when the ports are not unique' do
        it 'returns a 422 error' do
          post :create, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'CF-UnprocessableEntity'
          expect(response.body).to include 'The request is semantically invalid: a duplicate route mapping already exists'
        end
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

    context 'when ports are nil on the process' do
      let!(:app_process) { VCAP::CloudController::App.make(:process, app_guid: app.guid, type: process_type, space_guid: space.guid, ports: nil) }

      let(:req_body) do
        {
          relationships: {
            route: { guid: route.guid },
            app:   { guid: app.guid },
            process: { type: process_type }
          }
        }
      end

      context 'when the process type is web' do
        let(:process_type) { 'web' }

        it 'defaults the route mapping port to 8080' do
          post :create, body: req_body

          expect(response.status).to eq 201
          expect(VCAP::CloudController::RouteMappingModel.last.app_port).to eq(8080)
        end
      end
    end

    context 'when the requested port is not opened on the app' do
      let(:req_body) do
        {
          app_port: 1234,
          relationships: {
            route: { guid: route.guid },
            app:   { guid: app.guid }
          }
        }
      end

      it 'raises an API 400 error' do
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'Port 1234 is not available on the app'
      end

      context 'when no app_port is specified, but 8080 is not available on the app' do
        let(:app) { VCAP::CloudController::AppModel.make }
        let(:req_body) do
          {
            relationships: {
              route: { guid: route.guid },
              app:   { guid: app.guid }
            }
          }
        end

        before do
          app_process.health_check_type = 'none'
          app_process.ports = []
          app_process.save
        end

        it 'raises an API 422 error' do
          post :create, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'Port must be specified when app process does not have the default port 8080'
        end
      end
    end

    context 'when the mapping is invalid' do
      before do
        add_route_to_app = instance_double(VCAP::CloudController::RouteMappingCreate)
        allow(VCAP::CloudController::RouteMappingCreate).to receive(:new).and_return(add_route_to_app)
        allow(add_route_to_app).to receive(:add).and_raise(VCAP::CloudController::RouteMappingCreate::InvalidRouteMapping.new('shablam'))
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
          allow_user_read_access(user, space: space)
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

  describe '#show' do
    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
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
      allow_user_read_access(user, space: space)
      stub_readable_space_guids_for(user, space)
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
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200' do
          get :index, app_guid: app.guid
          expect(response.status).to eq 200
        end
      end
    end

    context 'permissions' do
      context 'admin' do
        before do
          set_current_user_as_admin(user: user)
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
      allow_user_read_access(user, space: space)
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
          allow_user_read_access(user, space: space)
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
