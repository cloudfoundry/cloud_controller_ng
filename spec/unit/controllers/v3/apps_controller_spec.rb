require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:app_model) { nil }
    let(:app_presenter) { double(:app_presenter) }
    let(:membership) { instance_double(Membership) }
    let(:roles) { instance_double(Roles) }
    let(:app_response) { 'app_response_body' }
    let(:apps_controller) do
      AppsV3Controller.new({},
                           logger,
                           { 'PATH_INFO' => '/v3/apps' },
                           params,
                           req_body,
                           nil,
                           { app_presenter: app_presenter })
    end

    before do
      allow(logger).to receive(:debug)
      allow(apps_controller).to receive(:membership).and_return(membership)
      allow(apps_controller).to receive(:current_user).and_return(User.make)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(app_presenter).to receive(:present_json).and_return(app_response)
      allow(Roles).to receive(:new).and_return(roles)
      allow(roles).to receive(:admin?).and_return(false)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:app) { AppModel.make }
      let(:fetcher) { double(:fetcher, fetch: [app]) }

      before do
        allow(app_presenter).to receive(:present_json_list).and_return(app_response)
        allow(apps_controller).to receive(:check_read_permissions!).and_return(true)
        allow(AppListFetcher).to receive(:new).and_return(fetcher)
        allow(membership).to receive(:space_guids_for_roles).and_return([app.space.guid]).
          with([Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = apps_controller.list

        expect(app_presenter).to have_received(:present_json_list).with([app], instance_of(AppsListMessage))
        expect(response_code).to eq(200)
        expect(response_body).to eq(app_response)
      end

      it 'checks for read permissions' do
        apps_controller.list

        expect(apps_controller).to have_received(:check_read_permissions!)
      end

      context 'query params' do
        context 'invalid param format' do
          let(:params) { { 'order_by' => '^%' } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Order by received an unsupported value')
            end
          end
        end

        context 'when the page is not an integer' do
          let(:params) { { 'page' => '1.1' } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Page must be an integer')
            end
          end
        end

        context 'unknown query param' do
          let(:bad_param) { 'foo' }
          let(:params) { { 'bad_param' => bad_param } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Unknown query param')
            end
          end
        end

        context 'invalid pagination' do
          let(:params) { { 'per_page' => 9999999999999999 } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Per page must be between')
            end
          end
        end
      end

      context 'admin' do
        let(:fetcher) { double(:fetcher, fetch_all: [app, app]) }

        before do
          allow(roles).to receive(:admin?).and_return(true)
        end

        it 'fetches all apps' do
          apps_controller.list
          expect(app_presenter).to have_received(:present_json_list).with([app, app], instance_of(AppsListMessage))
        end
      end
    end

    describe '#show' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }

      before do
        allow(apps_controller).to receive(:check_read_permissions!)
      end

      it 'returns a 200 and the app' do
        response_code, response = apps_controller.show(guid)

        expect(response_code).to eq 200
        expect(response).to eq(app_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 200 and the app' do
          response_code, response = apps_controller.show(guid)

          expect(response_code).to eq 200
          expect(response).to eq(app_response)
        end
      end

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

      context 'when the user does not have cc read scope' do
        it 'raises an ApiError with a 403 code' do
          expect(apps_controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            apps_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the user cannot read the app' do
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
            apps_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#create' do
      let(:space) { Space.make }
      let(:req_body) do
        {
          name: 'some-name',
          relationships: { space: { guid: space.guid } },
          lifecycle: { type: 'buildpack', data: { buildpack: 'http://some.url', stack: nil } }
        }.to_json
      end

      before do
        allow(apps_controller).to receive(:check_write_permissions!)
      end

      it 'checks for write permissions' do
        expect(apps_controller).to receive(:check_write_permissions!)
        apps_controller.create
      end

      it 'checks for proper roles' do
        apps_controller.create

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
            with([Membership::SPACE_DEVELOPER], space.guid)
      end

      it 'returns a 201 Created  and the app' do
        response_code, response = apps_controller.create
        expect(response_code).to eq 201
        expect(response).to eq(app_response)

        expect(AppModel.last.name).to eq('some-name')
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 201 Created and the app' do
          response_code, response = apps_controller.create
          expect(response_code).to eq 201
          expect(response).to eq(app_response)
        end
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

      context 'when the request has invalid data' do
        let(:req_body) { '{ "name": false }' }

        it 'returns an UnprocessableEntity error' do
          expect {
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
          end
        end
      end

      context 'when the app is invalid' do
        let(:app_create) { instance_double(AppCreate) }
        before do
          allow(app_create).to receive(:create).and_raise(AppCreate::InvalidApp.new('ya done goofed'))
          allow(AppCreate).to receive(:new).and_return(app_create)
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
          allow(membership).to receive(:has_any_roles?).and_return(false)
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

      context 'lifecycle data' do
        context 'when the requested buildpack is not a valid url and is not a known buildpack' do
          let(:req_body) do
            {
              name:       'some-name',
              relationships: { space: { guid: space.guid } },
              lifecycle: { type: 'buildpack', data: { buildpack: 'blawgow', stack: nil } }
            }.to_json
          end

          it 'returns an UnprocessableEntity error' do
            expect {
              apps_controller.create
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq(422)
              expect(error.message).to match('must be an existing admin buildpack or a valid git URI')
            end
          end
        end

        context 'when the space developer does not request lifecycle data' do
          let(:req_body) do
            {
              name: 'some-name',
              relationships: { space: { guid: space.guid } }
            }.to_json
          end
          it 'uses the defaults' do
            response_code, response = apps_controller.create
            created_app = AppModel.last

            expect(created_app.lifecycle_data.stack).to eq(Stack.default.name)
            expect(created_app.lifecycle_data.buildpack).to eq(nil)
            expect(response_code).to eq 201
            expect(response).to eq(app_response)
          end
        end

        context 'when the space developer requests lifecycle data' do
          context 'and leaves part of the data blank' do
            let(:req_body) do
              {
                name: 'some-name',
                relationships: { space: { guid: space.guid } },
                lifecycle: { type: 'buildpack', data: { buildpack: nil, stack: nil } }
              }.to_json
            end

            it 'creates the app with the lifecycle data, filling in defaults' do
              response_code, response = apps_controller.create
              created_app = AppModel.last

              expect(created_app.lifecycle_data.stack).to eq(Stack.default.name)
              expect(created_app.lifecycle_data.buildpack).to eq(nil)
              expect(response_code).to eq 201
              expect(response).to eq(app_response)
            end
          end

          context 'and they do not include the data section' do
            let(:req_body) do
              {
                name: 'some-name',
                relationships: { space: { guid: space.guid } },
                lifecycle: { type: 'buildpack' }
              }.to_json
            end

            it 'raises an error' do
              expect {
                apps_controller.create
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq(422)
                expect(error.message).
                  to match('The request is semantically invalid: Lifecycle data must be present, Lifecycle data must be a hash')
              end

              expect(AppModel.count).to eq(0)
            end
          end
        end
      end
    end

    describe '#update' do
      let(:app_model) { AppModel.make }
      let!(:app_lifecycle_data) do
        BuildpackLifecycleDataModel.make(
          app: app_model,
          buildpack: Buildpack.make,
          stack: Stack.default.name
        )
      end

      let!(:original_buildpack) { app_lifecycle_data.buildpack }
      let!(:original_stack) { app_lifecycle_data.stack }

      let(:space) { app_model.space }
      let(:org) { space.organization }

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
          end

          context 'when the user cannot read the app' do
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
                apps_controller.update(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the user can read but cannot write to the app' do
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
                apps_controller.update(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'NotAuthorized'
                expect(error.response_code).to eq 403
              end
            end
          end

          context 'when the app does not exist' do
            it 'raises an API 404 error' do
              expect {
                apps_controller.update('bogus')
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

        before do
          allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
        end

        it 'checks for the proper roles' do
          apps_controller.update(app_model.guid)

          expect(membership).to have_received(:has_any_roles?).at_least(1).times.
            with([Membership::SPACE_DEVELOPER], app_model.space.guid)
        end

        it 'returns a 200 OK and the app' do
          response_code, response = apps_controller.update(app_model.guid)
          expect(response_code).to eq 200
          expect(response).to eq(app_response)
        end

        context 'admin' do
          before do
            allow(roles).to receive(:admin?).and_return(true)
            allow(membership).to receive(:has_any_roles?).and_return(false)
          end

          it 'returns a 200 OK and the app' do
            response_code, response = apps_controller.update(app_model.guid)
            expect(response_code).to eq 200
            expect(response).to eq(app_response)
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

        context 'when the request has invalid data' do
          let(:req_body) { '{ "name": false }' }

          it 'returns an UnprocessableEntity error' do
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq(422)
            end
          end
        end

        context 'lifecycle data' do
          context 'when the user is setting the buildpack' do
            let(:buildpack_url) { 'http://some.url' }
            let(:req_body) do
              { name: new_name,
                lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: buildpack_url
                }
              } }.to_json
            end

            it 'sets the buildpack to the user provided buildpack' do
              apps_controller.update(app_model.guid)
              expect(app_model.reload.lifecycle_data.buildpack).to eq(buildpack_url)
            end
          end

          context 'when the user does not provide a buildpack' do
            let(:req_body) do
              { name: new_name,
                lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: nil
                }
              } }.to_json
            end

            it 'resets the buildpack' do
              expect(app_model.lifecycle_data.buildpack).to_not be_nil
              apps_controller.update(app_model.guid)
              expect(app_model.reload.lifecycle_data.buildpack).to be_nil
            end
          end

          context 'when the requested buildpack is not a valid url and is not a known buildpack' do
            let(:req_body) do
              {
                lifecycle: {
                  type: 'buildpack',
                  data: {
                    buildpack: 'blagow!'
                  }
                } }.to_json
            end

            it 'returns an UnprocessableEntity error' do
              expect {
                apps_controller.update(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq(422)
                expect(error.message).to match('must be an existing admin buildpack or a valid git URI')
              end
            end
          end

          context 'when a user specifies a stack' do
            context 'when the requested stack is valid' do
              let(:req_body) do
                { name: new_name,
                  lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'redhat'
                  }
                } }.to_json
              end

              before(:each) { Stack.create(name: 'redhat') }

              it 'sets the stack to the user provided stack' do
                apps_controller.update(app_model.guid)
                expect(app_model.lifecycle_data.stack).to eq('redhat')
              end
            end

            context 'when the requested stack is invalid' do
              let(:req_body) do
                { name: new_name,
                  lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'stacks on stacks lol'
                  }
                } }.to_json
              end

              it 'returns an UnprocessableEntity error' do
                expect {
                  apps_controller.update(app_model.guid)
                }.to raise_error do |error|
                  expect(error.name).to eq 'UnprocessableEntity'
                  expect(error.response_code).to eq(422)
                  expect(error.message).to include('Stack')
                end
              end
            end
          end

          context 'when a user does not provide any data' do
            let(:req_body) do
              { name: new_name,
                lifecycle: {
                type: 'buildpack',
                data: {
                }
              } }.to_json
            end

            it 'does not modify the lifecycle data' do
              expect(app_model.lifecycle_data.stack).to eq Stack.default.name
              apps_controller.update(app_model.guid)
              expect(app_model.reload.lifecycle_data.stack).to eq Stack.default.name
            end
          end
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

      context 'lifecycle data' do
        before do
          allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
        end

        context 'when the requested buildpack is not a valid url and is not a known buildpack' do
          let(:req_body) do
            {
              name:       'some-name',
              lifecycle: { type: 'buildpack', data: { buildpack: 'blawgow' } }
            }.to_json
          end

          it 'returns an UnprocessableEntity error' do
            expect {
              apps_controller.update(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq(422)
              expect(error.message).to match('must be an existing admin buildpack or a valid git URI')

              expect(app_model.lifecycle_data.stack).to eq(original_stack)
              expect(app_model.lifecycle_data.buildpack).to eq(original_buildpack)

              expect(app_lifecycle_data.stack).to eq(original_stack)
              expect(app_lifecycle_data.buildpack).to eq(original_buildpack)
            end
          end
        end

        context 'when the space developer does not request lifecycle data' do
          let(:req_body) do
            {
              name: 'some-name',
            }.to_json
          end
          it 'uses the data on app' do
            response_code, response = apps_controller.update(app_model.guid)
            expect(response_code).to eq 200
            expect(response).to eq(app_response)

            expect(app_model.lifecycle_data.stack).to eq(original_stack)
            expect(app_model.lifecycle_data.buildpack).to eq(original_buildpack)

            expect(app_lifecycle_data.stack).to eq(original_stack)
            expect(app_lifecycle_data.buildpack).to eq(original_buildpack)
          end
        end

        context 'when the space developer requests lifecycle data' do
          context 'and leaves part of the data blank' do
            let(:req_body) do
              {
                name: 'some-name',
                lifecycle: { type: 'buildpack', data: { buildpack: nil } }
              }.to_json
            end

            it 'updates the app with the lifecycle data provided' do
              response_code, response = apps_controller.update(app_model.guid)
              created_app = AppModel.last

              expect(created_app.lifecycle_data.stack).to eq(original_stack)
              expect(created_app.lifecycle_data.buildpack).to eq(nil)
              expect(response_code).to eq 200
              expect(response).to eq(app_response)

              expect(app_lifecycle_data.reload.stack).to eq(original_stack)
              expect(app_lifecycle_data.reload.buildpack).to eq(nil)
            end
          end

          context 'and they do not include the data section' do
            let(:req_body) do
              {
                name: 'some-name',
                lifecycle: { type: 'buildpack' }
              }.to_json
            end

            it 'raises an error' do
              expect {
                apps_controller.update(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq(422)
                expect(error.message).to include('Lifecycle data must be present')
                expect(error.message).to include('Lifecycle data must be a hash')
              end
            end
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space_guid: space.guid) }

      before do
        allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
      end

      it 'checks for the proper roles' do
        apps_controller.delete(app_model.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
          with([Membership::SPACE_DEVELOPER], space.guid)
      end

      it 'returns a 204' do
        response_code, _ = apps_controller.delete(app_model.guid)
        expect(response_code).to eq 204
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

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

        context 'when the user cannot read the app' do
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
              apps_controller.delete(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the user can read but cannot write to the app' do
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
              apps_controller.delete(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
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

    describe '#start' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:droplet) { DropletModel.make(process_types: { 'web' => 'a' }, app_guid: app_model.guid, state: DropletModel::STAGED_STATE) }

      before do
        allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
        app_model.update(droplet: droplet)
        app_model.save
      end

      it 'returns a 200 and the app' do
        response_code, response = apps_controller.start(app_model.guid)
        expect(response_code).to eq 200
        expect(response).to eq(app_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 200 and the app' do
          response_code, response = apps_controller.start(app_model.guid)
          expect(response_code).to eq 200
          expect(response).to eq(app_response)
        end
      end

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
          end

          it 'checks for the proper roles' do
            apps_controller.start(app_model.guid)

            expect(membership).to have_received(:has_any_roles?).at_least(1).times.
              with([Membership::SPACE_DEVELOPER], app_model.space.guid)
          end

          context 'when the app does not have a droplet' do
            before do
              droplet.destroy
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

          context 'when the user cannot read the app' do
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
                apps_controller.start(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the user can read but cannot write to the app' do
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
                apps_controller.start(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'NotAuthorized'
                expect(error.response_code).to eq 403
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

          context 'when the user has an invalid app' do
            let(:app_start) { instance_double(AppStart) }

            before do
              allow(AppStart).to receive(:new).and_return(app_start)
              allow(app_start).to receive(:start).and_raise(AppStart::InvalidApp.new)
            end

            it 'returns an UnprocessableEntity error' do
              expect {
                apps_controller.start(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end
      end
    end

    describe '#stop' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }

      before do
        allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
      end

      it 'returns a 200 and the app' do
        response_code, response = apps_controller.stop(app_model.guid)
        expect(response_code).to eq 200
        expect(response).to eq(app_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 200 and the app' do
          response_code, response = apps_controller.stop(app_model.guid)
          expect(response_code).to eq 200
          expect(response).to eq(app_response)
        end
      end

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
          end

          context 'when the user cannot read the app' do
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
                apps_controller.stop(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the user can read but cannot write to the app' do
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
                apps_controller.stop(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'NotAuthorized'
                expect(error.response_code).to eq 403
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

          context 'when the user has an invalid app' do
            let(:app_stop) { instance_double(AppStop) }

            before do
              allow(AppStop).to receive(:new).and_return(app_stop)
              allow(app_stop).to receive(:stop).and_raise(AppStop::InvalidApp.new)
            end

            it 'returns an UnprocessableEntity error' do
              expect {
                apps_controller.stop(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'UnprocessableEntity'
                expect(error.response_code).to eq 422
              end
            end
          end
        end
      end
    end

    describe '#get_environment' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }

      before do
        allow(apps_controller).to receive(:check_read_permissions!).and_return(nil)
      end

      it 'returns 200' do
        response_code, _ = apps_controller.get_environment(guid)
        expect(response_code).to eq(200)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns 200' do
          response_code, _ = apps_controller.get_environment(guid)
          expect(response_code).to eq(200)
        end
      end

      it 'checks for the proper roles' do
        apps_controller.get_environment(guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times.
          with([Membership::SPACE_DEVELOPER], app_model.space.guid)
      end

      context 'when the user does not have read permissions' do
        before do
          allow(apps_controller).to receive(:check_read_permissions!).and_raise(StandardError)
        end

        it 'returns a 403' do
          expect(apps_controller).to receive(:check_read_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            apps_controller.get_environment(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the user cannot read the app' do
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
            apps_controller.get_environment(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the app' do
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
            apps_controller.get_environment(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.get_environment(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe 'assign_current_droplet' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }
      let(:droplet) { DropletModel.make(process_types: { 'web' => 'start app' }, state: DropletModel::STAGED_STATE) }
      let(:droplet_guid) { droplet.guid }
      let(:req_body) { JSON.dump({ droplet_guid: droplet_guid }) }

      before do
        app_model.add_droplet(droplet)
        allow(apps_controller).to receive(:check_write_permissions!).and_return(nil)
      end

      it 'returns 200' do
        response_code, _ = apps_controller.assign_current_droplet(guid)
        expect(response_code).to eq(200)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns 200' do
          response_code, _ = apps_controller.assign_current_droplet(guid)
          expect(response_code).to eq(200)
        end
      end

      context 'bad json' do
        let(:req_body) { '{___O___O___}' }
        it 'returns 400 for bad json' do
          expect {
            apps_controller.assign_current_droplet(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      it 'doesnt let you if not stopped' do
        app_model.update(desired_state: 'STARTED')
        expect {
          apps_controller.assign_current_droplet(guid)
        }.to raise_error do |error|
          expect(error.name).to eq 'UnprocessableEntity'
          expect(error.response_code).to eq 422
        end
      end

      context 'when the application exists' do
        context 'when the user cannot update the application' do
          context 'when the user does not have write permissions' do
            it 'raises an ApiError with a 403 code' do
              expect(apps_controller).to receive(:check_write_permissions!).
                and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
              expect {
                apps_controller.assign_current_droplet(guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'NotAuthorized'
                expect(error.response_code).to eq 403
              end
            end
          end

          context 'when the user can not read the applicaiton' do
            before do
              allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
              allow(membership).to receive(:has_any_roles?).with(
                [Membership::SPACE_DEVELOPER,
                 Membership::SPACE_MANAGER,
                 Membership::SPACE_AUDITOR,
                 Membership::ORG_MANAGER], space.guid, org.guid).
                 and_return(false)
            end

            it 'returns a 404 ResourceNotFound' do
              expect {
                apps_controller.assign_current_droplet(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end

          context 'when the user cannot update the application' do
            before do
              allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
              allow(membership).to receive(:has_any_roles?).with(
                [Membership::SPACE_DEVELOPER,
                 Membership::SPACE_MANAGER,
                 Membership::SPACE_AUDITOR,
                 Membership::ORG_MANAGER], space.guid, org.guid).
                 and_return(true)
              allow(membership).to receive(:has_any_roles?).with(
                [Membership::SPACE_DEVELOPER], space.guid).
                 and_return(false)
            end

            it 'returns a 403 NotAuthorized' do
              expect {
                apps_controller.assign_current_droplet(app_model.guid)
              }.to raise_error do |error|
                expect(error.name).to eq 'NotAuthorized'
                expect(error.response_code).to eq 403
              end
            end
          end
        end

        context 'and the droplet is not associated with the application' do
          let(:req_body) { JSON.dump({ droplet_guid: 'bogus' }) }

          it 'returns a 404 ResourceNotFound' do
            expect {
              apps_controller.assign_current_droplet(app_model.guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the application does not exist' do
          it 'returns a 404 ResourceNotFound' do
            expect {
              apps_controller.assign_current_droplet('i do not exist')
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the app is invalid' do
          before do
            allow_any_instance_of(SetCurrentDroplet).to receive(:update_to).and_raise(SetCurrentDroplet::InvalidApp.new('app is broked'))
          end

          it 'returns an UnprocessableEntity error' do
            expect {
              apps_controller.assign_current_droplet(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnprocessableEntity'
              expect(error.response_code).to eq(422)
              expect(error.message).to match('app is broked')
            end
          end
        end
      end
    end
  end
end
