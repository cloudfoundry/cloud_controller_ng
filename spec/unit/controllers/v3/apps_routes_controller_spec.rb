require 'rails_helper'

describe AppsRoutesController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#add_route' do
    let(:space) { app.space }
    let(:org) { space.organization }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:route) { VCAP::CloudController::Route.make(space: space) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns 204 and associates the route with the app' do
      put :add_route, guid: app.guid, route_guid: route.guid

      expect(response.status).to eq(204)

      app.reload
      expect(app.routes).to include(route)
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        put :add_route, guid: app.guid, route_guid: route.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the route does not exist' do
      it 'raises an API 404 error' do
        put :add_route, guid: app.guid, route_guid: 'some-garbage'

        expect(response.status).to eq 404
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Route not found')
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :add_route, guid: 'bogus', route_guid: route.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have the required space and org roles' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        put :add_route, guid: app.guid, route_guid: route.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user can read but cannot write to the route' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
           and_return(true)

        allow(membership).to receive(:has_any_roles?).with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
          and_return(false)
      end

      it 'raises ApiError NotAuthorized' do
        put :add_route, guid: app.guid, route_guid: route.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the mapping is invalid' do
      before do
        add_route_to_app = instance_double(VCAP::CloudController::AddRouteToApp)
        allow(VCAP::CloudController::AddRouteToApp).to receive(:new).and_return(add_route_to_app)
        allow(add_route_to_app).to receive(:add).and_raise(VCAP::CloudController::AddRouteToApp::InvalidRouteMapping.new('shablam'))
      end

      it 'returns an UnprocessableEntity error' do
        put :add_route, guid: app.guid, route_guid: route.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 204' do
        put :add_route, guid: app.guid, route_guid: route.guid

        expect(response.status).to eq(204)
      end
    end
  end

  describe '#index' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:route_1) { VCAP::CloudController::Route.make(space: space) }
    let(:route_2) { VCAP::CloudController::Route.make(space: space) }
    let(:route_not_for_this_app) { VCAP::CloudController::Route.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::AppModelRoute.create(app: app_model, route: route_1, type: 'web')
      VCAP::CloudController::AppModelRoute.create(app: app_model, route: route_2, type: 'web')
    end

    it 'returns a 200' do
      get :index, guid: app_model.guid

      expect(response.status).to eq 200
    end

    it 'returns all the routes for the app' do
      get :index, guid: app_model.guid

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([route_1, route_2].map(&:guid))
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        get :index, guid: 'bogus-guid'

        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
        expect(response.status).to eq 404
      end
    end

    context 'when the user does not the required roles' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
           and_return(false)
      end

      it 'raises an API 404 error' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'raises an ApiError with a 403 code' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'succeeds' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 200
      end
    end
  end

  describe '#destroy' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::AppModelRoute.create(app: app_model, route: route, type: 'web')
    end

    it 'returns a 204' do
      delete :destroy, guid: app_model.guid, route_guid: route.guid

      expect(response.status).to eq 204
      expect(app_model.reload.routes).to be_empty
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'succeeds' do
        delete :destroy, guid: app_model.guid, route_guid: route.guid

        expect(response.status).to eq 204
        expect(app_model.reload.routes).to be_empty
      end
    end

    context 'when the route is mapped to multiple apps' do
      let(:another_app) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }

      before do
        VCAP::CloudController::AppModelRoute.create(app: another_app, route: route, type: 'web')
      end

      it 'removes only the mapping from the current app' do
        delete :destroy, guid: app_model.guid, route_guid: route.guid

        expect(response.status).to eq 204
        expect(app_model.reload.routes).to be_empty
        expect(another_app.reload.routes).to eq([route])
      end
    end

    context 'when the route is not mapped to the app' do
      let(:another_app) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }

      it 'raises an API 404 error' do
        delete :destroy, guid: another_app.guid, route_guid: route.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Route not found'
      end
    end

    context 'when the route does not exist' do
      it 'raises an API 404 error' do
        delete :destroy, guid: app_model.guid, route_guid: 'wut i do not exist'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Route not found'
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        delete :destroy, guid: 'lol', route_guid: route.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        delete :destroy, guid: app_model.guid, route_guid: route.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the user cannot read the route' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        delete :destroy, guid: app_model.guid, route_guid: route.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user can read but cannot write to the route' do
      before do
        allow(membership).to receive(:has_any_roles?).
          with([VCAP::CloudController::Membership::SPACE_DEVELOPER,
                VCAP::CloudController::Membership::SPACE_MANAGER,
                VCAP::CloudController::Membership::SPACE_AUDITOR,
                VCAP::CloudController::Membership::ORG_MANAGER],
                space.guid,
                org.guid).
          and_return(true)
        allow(membership).to receive(:has_any_roles?).
          with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
          and_return(false)
      end

      it 'raises ApiError NotAuthorized' do
        delete :destroy, guid: app_model.guid, route_guid: route.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end
end
