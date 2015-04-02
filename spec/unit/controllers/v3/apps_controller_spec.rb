require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:package_handler) { double(:package_handler) }
    let(:package_presenter) { double(:package_presenter) }
    let(:apps_handler) { double(:apps_handler) }
    let(:app_model) { nil }
    let(:app_presenter) { double(:app_presenter) }
    let(:apps_controller) do
      AppsV3Controller.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          apps_handler:      apps_handler,
          app_presenter:     app_presenter,
          packages_handler:  package_handler,
          package_presenter: package_presenter
        },
      )
    end
    let(:app_response) { 'app_response_body' }

    before do
      allow(logger).to receive(:debug)
      allow(apps_handler).to receive(:show).and_return(app_model)
      allow(app_presenter).to receive(:present_json).and_return(app_response)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:list_response) { 'list_response' }

      before do
        allow(app_presenter).to receive(:present_json_list).and_return(app_response)
        allow(apps_handler).to receive(:list).and_return(list_response)
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = apps_controller.list

        expect(apps_handler).to have_received(:list)
        expect(app_presenter).to have_received(:present_json_list).with(list_response, {})
        expect(response_code).to eq(200)
        expect(response_body).to eq(app_response)
      end

      context 'query params' do
        context('invalid param format') do
          let(:names) { 'foo' }
          let(:params) { { 'names' => names } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Invalid type')
            end
          end
        end

        context 'unknow query param' do
          let(:bad_param) { 'foo' }
          let(:params) { { 'bad_param' => bad_param } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Unknow query param')
            end
          end
        end
      end
    end

    describe '#show' do
      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }

        it 'returns a 200' do
          response_code, _ = apps_controller.show(guid)
          expect(response_code).to eq 200
        end

        it 'returns the app' do
          _, response = apps_controller.show(guid)
          expect(response).to eq(app_response)
        end
      end
    end

    describe '#create' do
      let(:space_guid) { Sham.guid }
      let(:req_body) do
        {
          name: 'some-name',
          space_guid: space_guid,
        }.to_json
      end
      let(:membership) { instance_double(Membership) }
      let(:app_create) { instance_double(AppCreate) }

      before do
        allow(apps_controller).to receive(:current_user).and_return(user)
        allow(apps_controller).to receive(:check_write_permissions!)
        allow(Membership).to receive(:new).and_return(membership)
        allow(membership).to receive(:space_role?).with(:developer, space_guid).and_return(true)
        allow(AppCreate).to receive(:new).and_return(app_create)
        allow(app_create).to receive(:create)
      end

      it 'checks for write permissions' do
        expect(apps_controller).to receive(:check_write_permissions!)
        apps_controller.create
      end

      context 'when the request body is invalid JSON' do
        let(:req_body) { '{ invalid_json }' }
        it 'returns an 400 Bad Request' do
          expect {
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the app is invalid' do
        before do
          allow(app_create).to receive(:create).and_raise(AppCreate::InvalidApp.new('ya done goofed'))
        end

        it 'returns an UnprocessableEntity error' do
          expect {
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('ya done goofed')
          end
        end
      end

      context 'when the user is not a member of the requested space' do
        before do
          allow(membership).to receive(:space_role?).with(:developer, space_guid).and_return(false)
        end

        it 'returns an NotFound error' do
          expect {
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to match('Space not found')
          end
        end
      end

      context 'when a user can create a app' do
        it 'returns a 201 Created response' do
          response_code, _ = apps_controller.create
          expect(response_code).to eq 201
        end

        it 'returns the app' do
          _, response = apps_controller.create
          expect(response).to eq(app_response)
        end
      end
    end

    describe '#update' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let!(:app_model) { AppModel.make }

      let(:new_name) { 'new-name' }
      let(:req_body) do
        {
          name: new_name,
        }.to_json
      end

      context 'when the user cannot update the application' do
        context 'when the user does not have write permissions' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end

        context 'when the user has write permissions' do
          before do
            allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
            allow(apps_controller).to receive(:current_user).and_return(user)
          end

          context 'when the user does not have space permissions' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.update(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the app does not exist' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.start('bogus')
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end

            context 'when the request body is invalid JSON' do
              let(:req_body) { '{ invalid_json }' }
              it 'returns an 400 Bad Request' do
                expect {
                  apps_controller.update(app_model.guid)
                }.to raise_error do |error|
                  expect(error.name).to eq 'MessageParseError'
                  expect(error.response_code).to eq 400
                end
              end
            end
          end
        end
      end

      context 'when the user can update the app' do
        let(:req_body) { { name: new_name }.to_json }
        let(:app_response) do
          {
            'guid' => app_model.guid,
            'name' => new_name,
          }
        end

        before do
          allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
          allow(apps_controller).to receive(:current_user).and_return(user)
          space = app_model.space
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'returns a 200 OK response' do
          response_code, _ = apps_controller.update(app_model.guid)
          expect(response_code).to eq 200
        end

        it 'returns the app information' do
          _, response = apps_controller.update(app_model.guid)
          expect(response).to eq(app_response)
        end

        context 'when the app is invalid' do
          let(:app_update) { double(:app_update) }
          before do
            allow(AppUpdate).to receive(:new).and_return(app_update)
            allow(app_update).to receive(:update).and_raise(AppUpdate::InvalidApp.new('ya done goofed'))
          end

          it 'returns an UnprocessableEntity error' do
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq(422)
              expect(error.message).to match('ya done goofed')
            end
          end
        end

        context 'when the droplet was not found' do
          let(:app_update) { double(:app_update) }
          before do
            allow(AppUpdate).to receive(:new).and_return(app_update)
            allow(app_update).to receive(:update).and_raise(AppUpdate::DropletNotFound.new)
          end

          it 'returns an NotFound error' do
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq(404)
            end
          end
        end

        context 'when the user attempts to set a reserved environment variable' do
          let(:req_body) do
            {
              environment_variables: {
                CF_GOOFY_GOOF: 'you done goofed!'
              }
            }.to_json
          end

          it 'returns the correct error' do
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq('UnprocessableEntity')
              expect(error.message).to match('The request is semantically invalid: environment_variables cannot start with CF_')
            end
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }

      before do
        allow(apps_controller).to receive(:current_user).and_return(user)
        allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when the app exists' do
        it 'returns a 204' do
          response_code, _ = apps_controller.delete(app_model.guid)
          expect(response_code).to eq 204
        end
      end

      context 'when the user cannot update the app' do
        context 'because they do not have write scope' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_controller.delete(app_model)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end

        context 'because they do not have the correct membership' do
          it 'raises an ApiError with a 404 code' do
            expect {
              apps_controller.delete(AppModel.make.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end
      end

      context 'when the app does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.delete('bogus')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe 'start' do
      let(:app_model) { AppModel.make }
      let(:user) { User.make }

      context 'when the user cannot start the application' do
        context 'when the user does not have write permissions' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_controller.start(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end

        context 'when the user has write permissions' do
          before do
            allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
            allow(apps_controller).to receive(:current_user).and_return(user)
          end

          context 'when the user has space permission' do
            context 'when the app does not have a droplet' do
              before do
                space = app_model.space
                space.organization.add_user(user)
                space.add_developer(user)
              end

              it 'raises an API 404 error' do
                expect {
                  apps_controller.start(app_model.guid)
                }.to raise_error do |error|
                  expect(error.name).to eq 'ResourceNotFound'
                  expect(error.response_code).to eq 404
                end
              end
            end
          end

          context 'when the user does not have space permissions' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.start(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the app does not exist' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.start('bogus')
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end
        end
      end
    end

    describe 'stop' do
      let(:app_model) { AppModel.make }
      let(:user) { User.make }

      context 'when the user cannot stop the application' do
        context 'when the user does not have write permissions' do
          it 'raises an ApiError with a 403 code' do
            expect(apps_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
            expect {
              apps_controller.stop(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end

        context 'when the user has write permissions' do
          before do
            allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
            allow(apps_controller).to receive(:current_user).and_return(user)
          end

          context 'when the user does not have space permissions' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.stop(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the app does not exist' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.stop('bogus')
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end
        end
      end
    end
    describe '#env' do
      let(:user) { User.make }
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }

      context 'when the user does not have read permissions' do
        it 'returns a 403' do
          # response_code, _ = apps_controller.env(guid)
          # expect(response_code).to eq 403
          expect(apps_controller).to receive(:check_read_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            apps_controller.env(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the user has read permissions' do
        before do
          allow(apps_controller).to receive(:check_read_permissions!).and_return(nil)
          allow(apps_controller).to receive(:current_user).and_return(user)
        end

        context 'when the app does not exist' do
          let(:guid) { 'ABC123' }

          it 'raises an ApiError with a 404 code' do
            expect {
              apps_controller.env(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end
      end
    end
  end
end
