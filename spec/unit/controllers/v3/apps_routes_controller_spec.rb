require 'spec_helper'

module VCAP::CloudController
  describe AppsRoutesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:params) { {} }
    let(:user) { User.make }
    let(:req_body) { '' }
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
    end

    describe 'add_route' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:route) { Route.make(space: space) }
      let(:req_body) { { route_guid: route.guid }.to_json }

      context 'when the user cannot add_route the application' do
        context 'when the user does not have write permissions' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_routes_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_routes_controller.add_route(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end

        context 'when the user has write permissions' do
          before do
            allow(apps_routes_controller).to receive(:check_write_permissions!).and_return(nil)
            allow(apps_routes_controller).to receive(:current_user).and_return(user)
          end

          context 'when the user has space permission' do
            context 'when the route does not exist' do
              let(:req_body) { { route_guid: 'some-garbage' }.to_json }

              before do
                space = app_model.space
                space.organization.add_user(user)
                space.add_developer(user)
              end

              it 'raises an API 404 error' do
                expect {
                  apps_routes_controller.add_route(app_model.guid)
                }.to raise_error do |error|
                  expect(error.name).to eq 'ResourceNotFound'
                  expect(error.message).to eq 'Route not found'
                  expect(error.response_code).to eq 404
                end
              end
            end
          end

          context 'when the user does not have space permissions' do
            it 'raises an API 404 error' do
              expect {
                apps_routes_controller.add_route(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.message).to eq 'App not found'
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
        end
      end
    end

    describe '#list' do
      let(:space) { Space.make }
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
          allow(apps_routes_controller).to receive(:current_user).and_return(user)
        end

        context 'when the user has space permission' do
          before do
            space = app_model.space
            space.organization.add_user(user)
            space.add_developer(user)
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
        end

        context 'when the user does not have space permissions' do
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
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:route) { Route.make(space: space) }
      let(:route_guid) { route.guid }
      let(:req_body) { { route_guid: route_guid }.to_json }

      before do
        AddRouteToApp.new(app_model).add(route)
      end

      context 'when the user cannot delete routes of the application' do
        context 'when the user does not have write permissions' do
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
      end

      context 'when the user has write permissions' do
        before do
          allow(apps_routes_controller).to receive(:check_write_permissions!).and_return(nil)
          allow(apps_routes_controller).to receive(:current_user).and_return(user)
        end

        context 'when the user has space permission' do
          before do
            space = app_model.space
            space.organization.add_user(user)
            space.add_developer(user)
          end

          context 'when the route is mapped to multiple apps' do
            let(:another_app) { AppModel.make(space_guid: space.guid) }
            before do
              AddRouteToApp.new(another_app).add(route)
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
        end

        context 'when the user does not have space permissions' do
          it 'raises an API 404 error' do
            expect {
              apps_routes_controller.delete(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.message).to eq 'App not found'
              expect(error.response_code).to eq 404
            end
          end
        end
      end
    end
  end
end
