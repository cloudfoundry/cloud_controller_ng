require 'rails_helper'

describe AppsV3Controller, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#list' do
    let(:app_model_1) { VCAP::CloudController::AppModel.make }
    let!(:app_model_2) { VCAP::CloudController::AppModel.make }
    let!(:space_1) { app_model_1.space }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(membership).to receive(:space_guids_for_roles).with(
        [VCAP::CloudController::Membership::SPACE_DEVELOPER,
         VCAP::CloudController::Membership::SPACE_MANAGER,
         VCAP::CloudController::Membership::SPACE_AUDITOR,
         VCAP::CloudController::Membership::ORG_MANAGER]).and_return(space_1.guid)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and lists the apps for spaces user is allowed to read' do
      get :index

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([app_model_1.guid])
    end

    context 'admin' do
      let!(:app_model_1) { VCAP::CloudController::AppModel.make }
      let!(:app_model_2) { VCAP::CloudController::AppModel.make }
      let!(:app_model_3) { VCAP::CloudController::AppModel.make }

      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_3, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
      end

      it 'fetches all the apps' do
        get :index

        response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([app_model_1, app_model_2, app_model_3].map(&:guid))
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
      end

      it 'raises an ApiError with a 403 code' do
        get :index

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'query params' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, order_by: '^=%'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
        end
      end

      context 'when the page is not an integer' do
        it 'returns 400' do
          get :index, page: 1.1

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include 'Page must be an integer'
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, meow: 'woof', kaplow: 'zoom'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Unknown query parameter(s): 'meow', 'kaplow'")
        end
      end

      context 'invalid pagination' do
        it 'returns 400' do
          get :index, per_page: 99999999999999999

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include 'Per page must be between'
        end
      end
    end
  end

  describe '#show' do
    let(:app_model) { VCAP::CloudController::AppModel.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      get :show, guid: app_model.guid

      expect(response.status).to eq 200
      expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 and the app' do
        get :show, guid: app_model.guid

        expect(response.status).to eq 200
        expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, guid: 'hahaha'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user does not have cc read scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
      end

      it 'raises an ApiError with a 403 code' do
        get :show, guid: app_model.guid

        expect(response.body).to include 'NotAuthorized'
        expect(response.status).to eq 403
      end
    end

    context 'when the user cannot read the app' do
      let(:space) { app_model.space }
      let(:org) { space.organization }

      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        get :show, guid: app_model.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#create' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:req_body) do
      {
        name: 'some-name',
        relationships: { space: { guid: space.guid } },
        lifecycle: { type: 'buildpack', data: { buildpack: 'http://some.url', stack: nil } }
      }
    end

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 201 Created and the app' do
      post :create, body: req_body

      app_model = space.app_models.last

      expect(response.status).to eq 201
      expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
      end

      it 'raises an ApiError with a 403 code' do
        get :create, body: req_body

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 201 Created and the app' do
        get :create, body: req_body
        app_model = space.app_models.last

        expect(response.status).to eq 201
        expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
      end
    end

    context 'when the request has invalid data' do
      let(:req_body) { { name: 200000 } }

      it 'returns an UnprocessableEntity error' do
        get :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the app is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppCreate).
          to receive(:create).
                and_raise(VCAP::CloudController::AppCreate::InvalidApp.new('ya done goofed'))
      end

      it 'returns an UnprocessableEntity error' do
        get :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'ya done goofed'
      end
    end

    context 'when the user is not a member of the requested space' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
                               and_return(false)
      end

      it 'returns an NotFound error' do
        get :create, body: req_body

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Space not found'
      end
    end

    context 'lifecycle data' do
      context 'when the requested buildpack is not a valid url and is not a known buildpack' do
        let(:req_body) do
          {
            name: 'some-name',
            relationships: { space: { guid: space.guid } },
            lifecycle: { type: 'buildpack', data: { buildpack: 'blawgow', stack: nil } }
          }
        end

        it 'returns an UnprocessableEntity error' do
          get :create, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'must be an existing admin buildpack or a valid git URI'
        end
      end

      context 'when the space developer does not request lifecycle data' do
        let(:req_body) do
          {
            name: 'some-name',
            relationships: { space: { guid: space.guid } }
          }
        end
        it 'uses the defaults and returns a 201 and the app' do
          get :create, body: req_body

          response_body = MultiJson.load(response.body)
          lifecycle_data = response_body['lifecycle']['data']

          expect(response.status).to eq 201
          expect(lifecycle_data['stack']).to eq VCAP::CloudController::Stack.default.name
          expect(lifecycle_data['buildpack']).to be_nil
        end
      end

      context 'when the space developer requests lifecycle data' do
        context 'and leaves part of the data blank' do
          let(:req_body) do
            {
              name: 'some-name',
              relationships: { space: { guid: space.guid } },
              lifecycle: { type: 'buildpack', data: { stack: 'cflinuxfs2' } }
            }
          end

          it 'creates the app with the lifecycle data, filling in defaults' do
            get :create, body: req_body

            response_body = MultiJson.load(response.body)
            lifecycle_data = response_body['lifecycle']['data']

            expect(response.status).to eq 201
            expect(lifecycle_data['stack']).to eq 'cflinuxfs2'
            expect(lifecycle_data['buildpack']).to be_nil
          end
        end

        context 'and they do not include the data section' do
          let(:req_body) do
            {
              name: 'some-name',
              relationships: { space: { guid: space.guid } },
              lifecycle: { type: 'buildpack' }
            }
          end

          it 'raises an UnprocessableEntity error' do
            get :create, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'The request is semantically invalid: Lifecycle data must be present, Lifecycle data must be a hash'
          end
        end
      end
    end
  end

  describe '#update' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:app_lifecycle_data) do
      VCAP::CloudController::BuildpackLifecycleDataModel.make(
        app: app_model,
        buildpack: VCAP::CloudController::Buildpack.make,
        stack: VCAP::CloudController::Stack.default.name
      )
    end

    let(:space) { app_model.space }
    let(:org) { space.organization }

    let(:req_body) { { name: 'new-name' } }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 200 OK and the app' do
      put :update, guid: app_model.guid, body: req_body

      expect(response.status).to eq 200
      expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
      expect(MultiJson.load(response.body)['name']).to eq('new-name')
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
      end

      it 'returns a 200 OK and the app' do
        put :update, guid: app_model.guid, body: req_body

        expect(response.status).to eq 200
        expect(MultiJson.load(response.body)['guid']).to eq(app_model.guid)
        expect(MultiJson.load(response.body)['name']).to eq('new-name')
      end
    end

    context 'when the request has invalid data' do
      let(:req_body) { { name: false } }

      context 'lifecycle data' do
        let(:new_name) { 'new freaking name' }

        context 'when the user specifies the buildpack' do
          let(:buildpack_url) { 'http://some.url' }
          let(:req_body) do
            { name: new_name,
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: buildpack_url
                }
              } }
          end

          it 'sets the buildpack to the provided buildpack' do
            put :update, guid: app_model.guid, body: req_body
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
              } }
          end

          it 'sets the buildpack to nil' do
            expect(app_model.lifecycle_data.buildpack).to_not be_nil
            put :update, guid: app_model.guid, body: req_body
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
              } }
          end

          it 'returns a 422 and an UnprocessableEntity error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('must be an existing admin buildpack or a valid git URI')
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
                } }
            end

            before(:each) { VCAP::CloudController::Stack.create(name: 'redhat') }

            it 'sets the stack to the user provided stack' do
              put :update, guid: app_model.guid, body: req_body
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
                } }
            end

            it 'returns an UnprocessableEntity error' do
              put :update, guid: app_model.guid, body: req_body

              expect(response.body).to include 'UnprocessableEntity'
              expect(response.status).to eq(422)
              expect(response.body).to include('Stack')
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
              } }
          end

          it 'does not modify the lifecycle data' do
            expect(app_model.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
            put :update, guid: app_model.guid, body: req_body
            expect(app_model.reload.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
          end
        end
      end

      context 'when the app is invalid' do
        it 'returns an UnprocessableEntity error' do
          put :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'The request is semantically invalid'
        end
      end

      context 'when the user attempts to set a reserved environment variable' do
        let(:req_body) do
          {
            environment_variables: {
              CF_GOOFY_GOOF: 'you done goofed!'
            }
          }
        end

        it 'returns the correct error' do
          put :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'The request is semantically invalid: environment_variables cannot start with CF_'
        end
      end

      context 'lifecycle data' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        end

        context 'when the requested buildpack is not a valid url and is not a known buildpack' do
          let(:req_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'buildpack', data: { buildpack: 'blawgow' } }
            }
          end

          it 'returns an UnprocessableEntity error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('must be an existing admin buildpack or a valid git URI')
          end
        end

        context 'when the space developer does not request lifecycle data' do
          let(:req_body) do
            {
              name: 'some-name',
            }
          end

          it 'uses the data on app' do
            put :update, guid: app_model.guid, body: req_body
            expect(response.status).to eq 200

            expect(app_model.lifecycle_data.stack).not_to be_nil
            expect(app_model.lifecycle_data.buildpack).not_to be_nil
          end
        end

        context 'when the space developer requests lifecycle data' do
          context 'and leaves part of the data blank' do
            let(:req_body) do
              {
                name: 'some-name',
                lifecycle: { type: 'buildpack', data: { buildpack: nil } }
              }
            end

            it 'updates the app with the lifecycle data provided' do
              put :update, guid: app_model.guid, body: req_body
              created_app = VCAP::CloudController::AppModel.last

              expect(created_app.lifecycle_data.stack).not_to be_nil
              expect(created_app.lifecycle_data.buildpack).to be_nil
              expect(response.status).to eq 200
            end
          end

          context 'and they do not include the data section' do
            let(:req_body) do
              {
                name: 'some-name',
                lifecycle: { type: 'buildpack' }
              }
            end

            it 'raises an error' do
              put :update, guid: app_model.guid, body: req_body

              expect(response.status).to eq 422
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include('Lifecycle data must be present')
              expect(response.body).to include('Lifecycle data must be a hash')
            end
          end
        end
      end
    end

    context 'when the user cannot read the app' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        put :update, guid: app_model.guid, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user can read but cannot write to the app' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }

      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        allow(membership).to receive(:has_any_roles?).
                               with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
                               and_return(false)
      end

      it 'raises ApiError NotAuthorized' do
        put :update, guid: app_model.guid, body: req_body

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end

  describe '#destroy' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 204' do
      delete :destroy, guid: app_model.guid

      expect(response.status).to eq 204
      expect { app_model.reload }.to raise_error(Sequel::Error, 'Record not found')
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 204' do
        delete :destroy, guid: app_model.guid

        expect(response.status).to eq 204
      end
    end

    context 'permissions' do
      context 'because they do not have the write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises an ApiError with a 403 code' do
          delete :destroy, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          delete :destroy, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
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
          delete :destroy, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        delete :destroy, guid: 'meowmeow'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#start' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :start, guid: app_model.guid

      response_body = MultiJson.load(response.body)

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['desired_state']).to eq('STARTED')
    end

    context 'permissions' do
      context 'admin' do
        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 200 and the app' do
          put :start, guid: app_model.guid

          response_body = MultiJson.load(response.body)

          expect(response.status).to eq 200
          expect(response_body['guid']).to eq app_model.guid
          expect(response_body['desired_state']).to eq 'STARTED'
        end
      end

      context 'when the user does not have write permissions' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises an ApiError with a 403 code' do
          put :start, guid: app_model.guid

          response_body = MultiJson.load(response.body)
          expect(response_body['error_code']).to eq 'CF-NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :start, guid: app_model.guid

          response_body = MultiJson.load(response.body)
          expect(response_body['error_code']).to eq 'CF-ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
      context 'when the user can read but cannot write to the app' do
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
          put :start, guid: app_model.guid

          response_body = MultiJson.load(response.body)
          expect(response_body['error_code']).to eq 'CF-NotAuthorized'
          expect(response.status).to eq 403
        end
      end
    end

    context 'when the app does not have a droplet' do
      before do
        droplet.destroy
      end

      it 'raises an API 404 error' do
        put :start, guid: app_model.guid

        response_body = MultiJson.load(response.body)
        expect(response_body['error_code']).to eq 'CF-ResourceNotFound'
        expect(response.status).to eq 404
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :start, guid: 'meowmeowmeow'

        response_body = MultiJson.load(response.body)
        expect(response_body['error_code']).to eq 'CF-ResourceNotFound'
        expect(response.status).to eq 404
      end
    end

    context 'when the user has an invalid app' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppStart).
          to receive(:start).
                and_raise(VCAP::CloudController::AppStart::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :start, guid: app_model.guid

        response_body = MultiJson.load(response.body)
        expect(response_body['error_code']).to eq 'CF-UnprocessableEntity'
        expect(response.status).to eq 422
      end
    end
  end

  describe '#stop' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid, desired_state: 'STARTED') }
    let(:droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :stop, guid: app_model.guid

      response_body = MultiJson.load(response.body)

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['desired_state']).to eq('STOPPED')
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 and the app' do
        put :stop, guid: app_model.guid

        response_body = MultiJson.load(response.body)

        expect(response.status).to eq 200
        expect(response_body['guid']).to eq(app_model.guid)
        expect(response_body['desired_state']).to eq('STOPPED')
      end
    end

    context 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises an ApiError with a 403 code' do
          put :stop, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :stop, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
                                 and_return(true)
          allow(membership).to receive(:has_any_roles?).
                                 with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
                                 and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          put :stop, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :stop, guid: 'thing'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user has an invalid app' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppStop).
          to receive(:stop).and_raise(VCAP::CloudController::AppStop::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :stop, guid: app_model.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end
  end

  describe '#show_environment' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { meep: 'moop', beep: 'boop' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the environment variables' do
      get :show_environment, guid: app_model.guid

      expect(response.status).to eq 200
      expect(MultiJson.load(response.body)['environment_variables']).to eq(app_model.environment_variables)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200' do
        get :show_environment, guid: app_model.guid

        expect(response.status).to eq(200)
        expect(MultiJson.load(response.body)['environment_variables']).to eq(app_model.environment_variables)
      end
    end

    context 'permissions' do
      context 'when the user does not have read permissions' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
        end

        it 'returns a 403' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
                                 and_return(true)
          allow(membership).to receive(:has_any_roles?).
                                 with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show_environment, guid: 'beep-boop'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#assign_current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:req_body) { { droplet_guid: droplet.guid } }
    let(:droplet_link) { { 'href' => "/v3/droplets/#{droplet.guid}" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      app_model.add_droplet(droplet)
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the app' do
      put :assign_current_droplet, guid: app_model.guid, body: req_body

      response_body = MultiJson.load(response.body)

      expect(response.status).to eq(200)
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['links']['droplet']).to eq(droplet_link)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        response_body = MultiJson.load(response.body)

        expect(response.status).to eq(200)
        expect(response_body['guid']).to eq(app_model.guid)
        expect(response_body['links']['droplet']).to eq(droplet_link)
      end
    end

    context 'and the droplet is not associated with the application' do
      let(:unassociated_droplet) { VCAP::CloudController::DropletModel.make }
      let(:req_body) { { droplet_guid: unassociated_droplet.guid } }

      it 'returns a 404 ResourceNotFound' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'and the droplet does not exist' do
      let(:req_body) { { droplet_guid: 'pitter-patter-zim-zoom' } }

      it 'returns a 404 ResourceNotFound' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        put :assign_current_droplet, guid: 'i do not exist', body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the app is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::SetCurrentDroplet).
          to receive(:update_to).
                and_raise(VCAP::CloudController::SetCurrentDroplet::InvalidApp.new('app is broked'))
      end

      it 'returns an UnprocessableEntity error' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the app is not stopped' do
      before do
        app_model.update(desired_state: 'STARTED')
      end

      it 'returns a 422 UnprocessableEntity error' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Stop the app before changing droplet'
      end
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises an ApiError with a 403 code' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user can not read the applicaiton' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
                                 and_return(false)
        end

        it 'returns a 404 ResourceNotFound' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user cannot update the application' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
                                 and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
                                 and_return(false)
        end

        it 'returns a 403 NotAuthorized' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end
end
