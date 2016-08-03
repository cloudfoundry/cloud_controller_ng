require 'rails_helper'

RSpec.describe AppsV3Controller, type: :controller do
  describe '#index' do
    let(:app_model_1) { VCAP::CloudController::AppModel.make }
    let!(:app_model_2) { VCAP::CloudController::AppModel.make }
    let!(:space_1) { app_model_1.space }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access(user, space: space_1)
      allow(controller).to receive(:readable_space_guids).and_return([space_1.guid])
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and lists the apps for spaces user is allowed to read' do
      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([app_model_1.guid])
    end

    context 'admin' do
      let!(:app_model_1) { VCAP::CloudController::AppModel.make }
      let!(:app_model_2) { VCAP::CloudController::AppModel.make }
      let!(:app_model_3) { VCAP::CloudController::AppModel.make }

      before do
        set_current_user_as_admin
        disallow_user_read_access(user, space: space_1)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_3, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
      end

      it 'fetches all the apps' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([app_model_1, app_model_2, app_model_3].map(&:guid))
      end
    end

    context 'read only admin' do
      let!(:app_model_1) { VCAP::CloudController::AppModel.make }
      let!(:app_model_2) { VCAP::CloudController::AppModel.make }
      let!(:app_model_3) { VCAP::CloudController::AppModel.make }

      before do
        allow(controller).to receive(:readable_space_guids).and_return([])
        disallow_user_read_access(user, space: space_1)
        set_current_user_as_admin_read_only

        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_3, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
      end

      it 'fetches all the apps' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([app_model_1, app_model_2, app_model_3].map(&:guid))
      end
    end

    context 'when the user does not have read scope' do
      before do
        set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
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
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access(user, space: space)
      allow_user_secret_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      get :show, guid: app_model.guid

      expect(response.status).to eq 200
      expect(parsed_body['guid']).to eq(app_model.guid)
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, guid: 'hahaha'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :show, guid: app_model.guid

          expect(response.body).to include 'NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end

  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:req_body) do
      {
        name: 'some-name',
        relationships: { space: { guid: space.guid } },
        lifecycle: { type: 'buildpack', data: { buildpack: 'http://some.url', stack: nil } }
      }
    end

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'returns a 201 Created and the app' do
      post :create, body: req_body

      app_model = space.app_models.last

      expect(response.status).to eq 201
      expect(parsed_body['guid']).to eq(app_model.guid)
    end

    context 'when the request has invalid data' do
      let(:req_body) { { name: 'missing-all-other-required-fields' } }

      it 'returns an UnprocessableEntity error' do
        post :create, req_body.to_json

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
        post :create, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'ya done goofed'
      end
    end

    context 'lifecycle data' do
      context 'when the space developer does not request a lifecycle' do
        let(:req_body) do
          {
            name:          'some-name',
            relationships: { space: { guid: space.guid } }
          }
        end

        it 'uses the defaults and returns a 201 and the app' do
          post :create, body: req_body

          response_body  = parsed_body
          lifecycle_data = response_body['lifecycle']['data']

          expect(response.status).to eq 201
          expect(lifecycle_data['stack']).to eq VCAP::CloudController::Stack.default.name
          expect(lifecycle_data['buildpack']).to be_nil
        end
      end

      context 'buildpack' do
        context 'when the space developer requests lifecycle data' do
          context 'and leaves part of the data blank' do
            let(:req_body) do
              {
                name:          'some-name',
                relationships: { space: { guid: space.guid } },
                lifecycle:     { type: 'buildpack', data: { stack: 'cflinuxfs2' } }
              }
            end

            it 'creates the app with the lifecycle data, filling in defaults' do
              post :create, body: req_body

              response_body  = parsed_body
              lifecycle_data = response_body['lifecycle']['data']

              expect(response.status).to eq 201
              expect(lifecycle_data['stack']).to eq 'cflinuxfs2'
              expect(lifecycle_data['buildpack']).to be_nil
            end
          end

          context 'when the requested buildpack is not a valid url and is not a known buildpack' do
            let(:req_body) do
              {
                name:          'some-name',
                relationships: { space: { guid: space.guid } },
                lifecycle:     { type: 'buildpack', data: { buildpack: 'blawgow', stack: nil } }
              }
            end

            it 'returns an UnprocessableEntity error' do
              post :create, body: req_body

              expect(response.status).to eq 422
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include 'must be an existing admin buildpack or a valid git URI'
            end
          end

          context 'and they do not include the data section' do
            let(:req_body) do
              {
                name:          'some-name',
                relationships: { space: { guid: space.guid } },
                lifecycle:     { type: 'buildpack' }
              }
            end

            it 'raises an UnprocessableEntity error' do
              post :create, body: req_body

              expect(response.status).to eq(422)
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include 'The request is semantically invalid: Lifecycle data must be a hash'
            end
          end
        end
      end

      context 'docker' do
        context 'when lifecycle data is not empty' do
          let(:req_body) do
            {
              name:          'some-name',
              relationships: { space: { guid: space.guid } },
              lifecycle:     { type: 'docker', data: { foo: 'bar' } }
            }
          end

          it 'raises an UnprocessableEntity error' do
            post :create, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include "Lifecycle Unknown field(s): 'foo'"
          end
        end

        context 'when lifecycle data is not a hash' do
          let(:req_body) do
            {
              name:          'some-name',
              relationships: { space: { guid: space.guid } },
              lifecycle:     { type: 'docker', data: 'yay' }
            }
          end

          it 'raises an UnprocessableEntity error' do
            post :create, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'The request is semantically invalid: Lifecycle data must be a hash'
          end
        end
      end
    end

    context 'when the space does not exist' do
      before do
        req_body[:relationships][:space][:guid] = 'made-up'
      end

      it 'returns 404 space not found' do
        post :create, body: req_body

        expect(response).to have_status_code(404)
        expect(response.body).to include('Space not found')
      end
    end

    context 'when requesting docker lifecycle and diego_docker feature flag is disabled' do
      let(:req_body) do
        {
          name:          'some-name',
          relationships: { space: { guid: space.guid } },
          lifecycle:     { type: 'docker', data: {} }
        }
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
      end

      context 'admin' do
        before do
          set_current_user_as_admin(user: user)
        end

        it 'raises 403' do
          post :create, body: req_body
          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end

      context 'non-admin' do
        it 'raises 403' do
          post :create, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end
    end

    context 'permissions' do
      context 'when the user is not a member of the requested space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns an NotFound error' do
          post :create, body: req_body

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Space not found'
        end
      end

      context 'when the user does not have write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          post :create, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user is a space manager/org manager and thus can see the space but not create apps' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns an Unauthorized error' do
          post :create, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#update' do
    let(:app_model) { VCAP::CloudController::AppModel.make(:buildpack) }

    let(:space) { app_model.space }
    let(:org) { space.organization }

    let(:req_body) { { name: 'new-name' } }

    before do
      user = VCAP::CloudController::User.make
      set_current_user(user)
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'returns a 200 OK and the app' do
      put :update, guid: app_model.guid, body: req_body

      expect(response.status).to eq 200
      expect(parsed_body['guid']).to eq(app_model.guid)
      expect(parsed_body['name']).to eq('new-name')
    end

    context 'when the request has invalid data' do
      let(:req_body) { { name: false } }

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
    end

    context 'lifecycle data' do
      let(:new_name) { 'potato' }

      context 'when the space developer does not request lifecycle' do
        let(:req_body) do
          {
            name: new_name,
          }
        end

        context 'buildpack app' do
          before do
            app_model.lifecycle_data.stack = 'some-stack-name'
            app_model.lifecycle_data.buildpack = 'some-buildpack-name'
            app_model.lifecycle_data.save
          end

          it 'uses the existing lifecycle on app' do
            put :update, guid: app_model.guid, body: req_body
            expect(response.status).to eq 200

            app_model.reload
            app_model.lifecycle_data.reload

            expect(app_model.name).to eq(new_name)
            expect(app_model.lifecycle_data.stack).to eq('some-stack-name')
            expect(app_model.lifecycle_data.buildpack).to eq('some-buildpack-name')
          end
        end

        context 'docker app' do
          let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

          it 'uses the existing lifecycle on app' do
            put :update, guid: app_model.guid, body: req_body
            expect(response.status).to eq 200

            app_model.reload

            expect(app_model.name).to eq(new_name)
            expect(app_model.lifecycle_type).to eq('docker')
          end
        end
      end

      context 'buildpack request' do
        context 'when the requested buildpack is not a valid url and is not a known buildpack' do
          let(:req_body) do
            {
              name:      'some-name',
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

        context 'when the user specifies the buildpack' do
          let(:buildpack_url) { 'http://some.url' }
          let(:req_body) do
            { name:      new_name,
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

        context 'when the user requests a nil buildpack' do
          let(:req_body) do
            { name:      new_name,
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

        context 'when a user specifies a stack' do
          context 'when the requested stack is valid' do
            let(:req_body) do
              {
                name:      new_name,
                lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'redhat'
                  }
                }
              }
            end

            before(:each) { VCAP::CloudController::Stack.create(name: 'redhat') }

            it 'sets the stack to the user provided stack' do
              put :update, guid: app_model.guid, body: req_body
              expect(app_model.lifecycle_data.stack).to eq('redhat')
            end
          end

          context 'when the requested stack is invalid' do
            let(:req_body) do
              {
                name:      new_name,
                lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'stacks on stacks lol'
                  }
                }
              }
            end

            it 'returns an UnprocessableEntity error' do
              put :update, guid: app_model.guid, body: req_body

              expect(response.body).to include 'UnprocessableEntity'
              expect(response.status).to eq(422)
              expect(response.body).to include('Stack')
            end
          end
        end

        context 'when a user provides empty lifecycle data' do
          let(:req_body) do
            {
              name:      new_name,
              lifecycle: {
                type: 'buildpack',
                data: {}
              }
            }
          end

          before do
            app_model.lifecycle_data.stack = VCAP::CloudController::Stack.default.name
            app_model.lifecycle_data.save
          end

          it 'does not modify the lifecycle data' do
            expect(app_model.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
            put :update, guid: app_model.guid, body: req_body
            expect(app_model.reload.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
          end
        end

        context 'when the space developer requests a lifecycle without a data key' do
          let(:req_body) do
            {
              name:      'some-name',
              lifecycle: { type: 'buildpack' }
            }
          end

          it 'raises an error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle data must be a hash')
          end
        end

        context 'when attempting to change to another lifecycle type' do
          let(:req_body) do
            {
              name:      'some-name',
              lifecycle: { type: 'docker', data: {} }
            }
          end

          it 'raises an error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle type cannot be changed')
          end
        end
      end

      context 'docker request' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

        context 'when attempting to change to another lifecycle type' do
          let(:req_body) do
            {
              name:      'some-name',
              lifecycle: { type: 'buildpack', data: {} }
            }
          end

          it 'raises an error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle type cannot be changed')
          end
        end

        context 'when a user provides empty lifecycle data' do
          let(:req_body) do
            {
              name:      'some-name',
              lifecycle: {
                type: 'docker',
                data: {}
              }
            }
          end

          it 'does not fail' do
            put :update, guid: app_model.guid, body: req_body
            expect(response).to have_status_code(200)
          end
        end

        context 'when the space developer requests a lifecycle without a data key' do
          let(:req_body) do
            {
              name:      'some-name',
              lifecycle: { type: 'docker' }
            }
          end

          it 'raises an error' do
            put :update, guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle data must be a hash')
          end
        end
      end
    end

    context 'permissions' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:user) { set_current_user(VCAP::CloudController::User.make) }

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          put :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#destroy' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 204' do
      delete :destroy, guid: app_model.guid

      expect(response.status).to eq 204
      expect { app_model.reload }.to raise_error(Sequel::Error, 'Record not found')
    end

    context 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          delete :destroy, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          delete :destroy, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
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

    context 'when AppDelete::InvalidDelete is raised' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppDelete).to receive(:delete).
          and_raise(VCAP::CloudController::AppDelete::InvalidDelete.new('it is broke'))
      end

      it 'returns a 400' do
        delete :destroy, guid: app_model.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'it is broke'
      end
    end
  end

  describe '#start' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :start, guid: app_model.guid

      response_body = parsed_body

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['desired_state']).to eq('STARTED')
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :start, guid: app_model.guid

          response_body = parsed_body
          expect(response_body['error_code']).to eq 'CF-NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :start, guid: app_model.guid

          response_body = parsed_body
          expect(response_body['error_code']).to eq 'CF-ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          put :start, guid: app_model.guid

          response_body = parsed_body
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

        response_body = parsed_body
        expect(response_body['error_code']).to eq 'CF-ResourceNotFound'
        expect(response.status).to eq 404
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :start, guid: 'meowmeowmeow'

        response_body = parsed_body
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

        response_body = parsed_body
        expect(response_body['error_code']).to eq 'CF-UnprocessableEntity'
        expect(response.status).to eq 422
      end
    end

    context 'when requesting docker lifecycle and diego_docker feature flag is disabled' do
      let(:droplet) { VCAP::CloudController::DropletModel.make(:docker, state: VCAP::CloudController::DropletModel::STAGED_STATE) }

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
      end

      context 'admin' do
        before do
          set_current_user_as_admin(user: user)
        end

        it 'raises 403' do
          put :start, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end

      context 'non-admin' do
        it 'raises 403' do
          put :start, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end
    end
  end

  describe '#stop' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid, desired_state: 'STARTED') }
    let(:droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :stop, guid: app_model.guid

      response_body = parsed_body

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['desired_state']).to eq('STOPPED')
    end

    context 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :stop, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :stop, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
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
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the environment variables' do
      allow(controller).to receive(:can_see_secrets?).and_return(true)
      get :show_environment, guid: app_model.guid

      expect(response.status).to eq 200
      expect(parsed_body['environment_variables']).to eq(app_model.environment_variables)
    end

    context 'permissions' do
      context 'when the user does not have read permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
        end

        it 'returns a 403' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when user can see secrets' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(true)
        end

        it 'succeeds' do
          get :show_environment, guid: app_model.guid
          expect(response.status).to eq(200)
        end
      end

      context 'when user can not see secrets' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(true)
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for non-admins' do
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('space_developer_env_var_visibility')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin(user: user)
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq(200)
        end

        it 'succeeds for admins_read_only' do
          set_current_user_as_admin_read_only(user: user)
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq(200)
        end

        context 'when user can not see secrets' do
          before do
            allow(controller).to receive(:can_see_secrets?).and_return(false)
          end

          it 'raises ApiError NotAuthorized as opposed to FeatureDisabled' do
            get :show_environment, guid: app_model.guid

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end
      end

      context 'when the env_var_visibility feature flag is disabled' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(true)
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for all users' do
          set_current_user_as_admin(user: user)
          get :show_environment, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('Feature Disabled: env_var_visibility')
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
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the droplet' do
      put :assign_current_droplet, guid: app_model.guid, body: req_body

      response_body = parsed_body

      expect(response.status).to eq(200)
      expect(response_body['guid']).to eq(droplet.guid)
      expect(response_body['links']['self']).to eq(droplet_link)
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
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user can not read the application' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but not update the application' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403 NotAuthorized' do
          put :assign_current_droplet, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe 'current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_link) { { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access(user, space: space)
    end

    it 'returns a 200 OK and the droplet' do
      get :current_droplet, guid: app_model.guid

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(droplet.guid)
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        get :current_droplet, guid: 'i do not exist'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the current droplet is not set' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns a 404 Not Found' do
        get :current_droplet, guid: app_model.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have the read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'returns a 403 NotAuthorized error' do
          get :current_droplet, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user can not read the space' do
        let(:space) { droplet.space }
        let(:org) { space.organization }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 not found' do
          get :current_droplet, guid: app_model.guid

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not update the application' do
        let(:space) { droplet.space }
        let(:org) { space.organization }

        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200 OK' do
          get :current_droplet, guid: app_model.guid

          expect(response.status).to eq(200)
        end
      end
    end
  end
end
