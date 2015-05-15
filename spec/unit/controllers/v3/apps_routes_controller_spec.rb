require 'spec_helper'

module VCAP::CloudController
  describe AppsRoutesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:params) { {} }
    let(:req_body) { '' }
    let(:membership) { double(:membership) }
    let(:apps_routes_controller) do
      AppsRoutesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {},
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(apps_routes_controller).to receive(:membership).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    describe '#add_route' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app) { AppModel.make(space_guid: space.guid) }
      let(:route) { Route.make(space: space) }
      let(:req_body) { { route_guid: route.guid }.to_json }

      before do
        allow(apps_routes_controller).to receive(:check_write_permissions!).and_return(nil)
      end

      it 'checks for the proper roles' do
        apps_routes_controller.add_route(app.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
            with([Membership::SPACE_DEVELOPER], space.guid)
      end

      context 'when the user does not have write permissions' do
        before do
          allow(apps_routes_controller).to receive(:check_write_permissions!).and_raise('cannot write')
        end

        it 'raises an ApiError with a 403 code' do
          expect(apps_routes_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            apps_routes_controller.add_route(app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the route does not exist' do
        let(:req_body) { { route_guid: 'some-garbage' }.to_json }

        it 'raises an API 404 error' do
          expect {
            apps_routes_controller.add_route(app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'Route not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does not exist' do
        it 'raises an API 404 error' do
          expect {
            apps_routes_controller.add_route('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'App not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the route' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            apps_routes_controller.add_route(app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the route' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).
              and_return(true)
          allow(membership).to receive(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid).
              and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          expect {
            apps_routes_controller.add_route(app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the mapping is invalid' do
        before do
          allow(AddRouteToApp).to receive(:new).and_raise(AddRouteToApp::InvalidRouteMapping.new('shablam'))
        end

        it 'returns an UnprocessableEntity error' do
          expect {
            apps_routes_controller.add_route(app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end
    end

    describe '#list' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space_guid: space.guid) }

      context 'when the user cannot list routes of the application' do
        context 'when the user does not have read permissions' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_routes_controller).to receive(:check_read_permissions!).
                and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_routes_controller.list(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end
      end

      context 'when the user has read permissions' do
        before do
          allow(apps_routes_controller).to receive(:check_read_permissions!).and_return(nil)
        end

        it 'checks for the proper roles' do
          apps_routes_controller.list(app_model.guid)

          expect(membership).to have_received(:has_any_roles?).
              with([Membership::SPACE_DEVELOPER,
                    Membership::SPACE_MANAGER,
                    Membership::SPACE_AUDITOR,
                    Membership::ORG_MANAGER
                   ], space.guid, org.guid)
        end

        context 'when the app does not exist' do
          it 'raises an API 404 error' do
            expect {
              apps_routes_controller.list('bogus')
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.message).to eq 'App not found'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the user does not have required roles' do
          before do
            allow(membership).to receive(:has_any_roles?).and_return(false)
          end

          it 'raises an API 404 error' do
            expect {
              apps_routes_controller.list(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.message).to eq 'App not found'
              expect(error.response_code).to eq 404
            end
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:route) { Route.make(space: space) }
      let(:route_guid) { route.guid }
      let(:req_body) { { route_guid: route_guid }.to_json }

      before do
        AppModelRoute.create(app: app_model, route: route, type: 'web')
        allow(apps_routes_controller).to receive(:check_write_permissions!).and_return(nil)
      end

      it 'checks for the proper roles' do
        apps_routes_controller.delete(app_model.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
            with([Membership::SPACE_DEVELOPER], space.guid)
      end

      context 'when the route is mapped to multiple apps' do
        let(:another_app) { AppModel.make(space_guid: space.guid) }
        before do
          AppModelRoute.create(app: another_app, route: route, type: 'web')
        end

        it 'removes only the mapping from the current app' do
          apps_routes_controller.delete(app_model.guid)
          expect(app_model.reload.routes).to be_empty
          expect(another_app.reload.routes).to eq([route])
        end
      end

      context 'when the route is not mapped to the app' do
        let(:another_app) { AppModel.make(space_guid: space.guid) }

        it 'raises an API 404 error' do
          expect {
            apps_routes_controller.delete(another_app.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'Route not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the route does not exist' do
        let(:route_guid) { 'bogus' }

        it 'raises an API 404 error' do
          expect {
            apps_routes_controller.delete(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'Route not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does not exist' do
        it 'raises an API 404 error' do
          expect {
            apps_routes_controller.delete('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'App not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user does not have write permissions' do
        before do
          allow(apps_routes_controller).to receive(:check_write_permissions!).and_raise('permission error')
        end

        it 'raises an ApiError with a 403 code' do
          expect(apps_routes_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            apps_routes_controller.delete(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the user cannot read the route' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            apps_routes_controller.delete(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the route' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).
              and_return(true)
          allow(membership).to receive(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid).
              and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          expect {
            apps_routes_controller.delete(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end
    end
  end
end
