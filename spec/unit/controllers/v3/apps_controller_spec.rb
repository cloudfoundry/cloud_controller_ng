require 'rails_helper'

RSpec.describe AppsV3Controller, type: :controller do
  describe '#index' do
    let(:app_model_1) { VCAP::CloudController::AppModel.make }
    let!(:app_model_2) { VCAP::CloudController::AppModel.make }
    let!(:space_1) { app_model_1.space }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space_1])
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and lists the apps for spaces user is allowed to read' do
      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([app_model_1.guid])
    end

    context 'when the user has global read access' do
      let!(:app_model_1) { VCAP::CloudController::AppModel.make }
      let!(:app_model_2) { VCAP::CloudController::AppModel.make }
      let!(:app_model_3) { VCAP::CloudController::AppModel.make }

      before do
        allow_user_global_read_access(user)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_1, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_2, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model_3, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
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
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at', 'name'")
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
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
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
        name:          'some-name',
        relationships: { space: { data: { guid: space.guid } } },
        lifecycle:     { type: 'buildpack', data: { buildpacks: ['http://some.url'], stack: nil } }
      }
    end

    before do
      allow_user_read_access_for(user, spaces: [space])
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
        allow_any_instance_of(VCAP::CloudController::AppCreate).to receive(:create).
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
            relationships: { space: { data: { guid: space.guid } } }
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
                relationships: { space: { data: { guid: space.guid } } },
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
                relationships: { space: { data: { guid: space.guid } } },
                lifecycle:     { type: 'buildpack', data: { buildpacks: ['blawgow'], stack: nil } }
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
                relationships: { space: { data: { guid: space.guid } } },
                lifecycle:     { type: 'buildpack' }
              }
            end

            it 'raises an UnprocessableEntity error' do
              post :create, body: req_body

              expect(response.status).to eq(422)
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include 'Lifecycle data must be a hash'
            end
          end
        end
      end

      context 'docker' do
        context 'when lifecycle data is not empty' do
          let(:req_body) do
            {
              name:          'some-name',
              relationships: { space: { data: { guid: space.guid } } },
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
              relationships: { space: { data: { guid: space.guid } } },
              lifecycle:     { type: 'docker', data: 'yay' }
            }
          end

          it 'raises an UnprocessableEntity error' do
            post :create, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'Lifecycle data must be a hash'
          end
        end
      end
    end

    context 'when the space does not exist' do
      before do
        req_body[:relationships][:space][:data][:guid] = 'made-up'
      end

      it 'returns an UnprocessableEntity error' do
        post :create, body: req_body

        expect(response).to have_status_code(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include('Invalid space. Ensure that the space exists and you have access to it.')
      end
    end

    context 'when requesting docker lifecycle and diego_docker feature flag is disabled' do
      let(:req_body) do
        {
          name:          'some-name',
          relationships: { space: { data: { guid: space.guid } } },
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

        it 'returns an UnprocessableEntity error' do
          post :create, body: req_body

          expect(response).to have_status_code(422)
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include('Invalid space. Ensure that the space exists and you have access to it.')
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
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns an Unauthorized error' do
          post :create, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include('Invalid space. Ensure that the space exists and you have access to it.')
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
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'returns a 200 OK and the app' do
      patch :update, guid: app_model.guid, body: req_body

      expect(response.status).to eq 200
      expect(parsed_body['guid']).to eq(app_model.guid)
      expect(parsed_body['name']).to eq('new-name')
    end

    context 'when the request has invalid data' do
      let(:req_body) { { name: false } }

      context 'when the app is invalid' do
        it 'returns an UnprocessableEntity error' do
          patch :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
        end
      end
    end

    context 'lifecycle data' do
      let(:new_name) { 'potato' }
      before do
        VCAP::CloudController::Buildpack.make(name: 'some-buildpack-name')
        VCAP::CloudController::Buildpack.make(name: 'some-buildpack')
      end

      context 'when the space developer does not request lifecycle' do
        let(:req_body) do
          {
            name: new_name,
          }
        end

        context 'buildpack app' do
          before do
            app_model.lifecycle_data.stack      = 'some-stack-name'
            app_model.lifecycle_data.buildpacks = ['some-buildpack-name', 'http://buildpack.com']
            app_model.lifecycle_data.save
          end

          it 'uses the existing lifecycle on app' do
            patch :update, guid: app_model.guid, body: req_body
            expect(response.status).to eq 200

            app_model.reload
            app_model.lifecycle_data.reload

            expect(app_model.name).to eq(new_name)
            expect(app_model.lifecycle_data.stack).to eq('some-stack-name')
            expect(app_model.lifecycle_data.buildpacks).to eq(['some-buildpack-name', 'http://buildpack.com'])
          end
        end

        context 'docker app' do
          let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

          it 'uses the existing lifecycle on app' do
            patch :update, guid: app_model.guid, body: req_body
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
              lifecycle: { type: 'buildpack', data: { buildpacks: ['blawgow'] } }
            }
          end

          it 'returns an UnprocessableEntity error' do
            patch :update, guid: app_model.guid, body: req_body

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
                  buildpacks: [buildpack_url]
                }
              } }
          end

          it 'sets the buildpack to the provided buildpack' do
            patch :update, guid: app_model.guid, body: req_body
            expect(app_model.reload.lifecycle_data.buildpacks).to eq([buildpack_url])
          end
        end

        context 'when the user requests a nil buildpack' do
          let(:req_body) do
            { name:      new_name,
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: nil
                }
              } }
          end

          before do
            app_model.lifecycle_data.buildpacks = ['some-buildpack']
            app_model.lifecycle_data.save
          end

          it 'sets the buildpack to nil' do
            expect(app_model.lifecycle_data.buildpacks).to_not be_empty
            patch :update, guid: app_model.guid, body: req_body
            expect(app_model.reload.lifecycle_data.buildpacks).to be_empty
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
              patch :update, guid: app_model.guid, body: req_body
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
              patch :update, guid: app_model.guid, body: req_body

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
            patch :update, guid: app_model.guid, body: req_body
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
            patch :update, guid: app_model.guid, body: req_body

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
            patch :update, guid: app_model.guid, body: req_body

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
            patch :update, guid: app_model.guid, body: req_body

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
            patch :update, guid: app_model.guid, body: req_body
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
            patch :update, guid: app_model.guid, body: req_body

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
          patch :update, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          patch :update, guid: app_model.guid, body: req_body

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
    let(:app_delete_stub) { instance_double(VCAP::CloudController::AppDelete) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
      allow(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::AppDelete).to receive(:new).and_return(app_delete_stub)
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
          allow_user_read_access_for(user, spaces: [space])
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

    it 'successfully deletes the app in a background job' do
      delete :destroy, guid: app_model.guid

      app_delete_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppDelete%'"))
      expect(app_delete_jobs.count).to eq 1
      app_delete_jobs.first

      expect(VCAP::CloudController::AppModel.find(guid: app_model.guid)).not_to be_nil
      expect(VCAP::CloudController::Jobs::DeleteActionJob).to have_received(:new).with(
        VCAP::CloudController::AppModel,
        app_model.guid,
        app_delete_stub,
      )
    end

    it 'creates a job to track the deletion and returns it in the location header' do
      expect {
        delete :destroy, guid: app_model.guid
      }.to change {
        VCAP::CloudController::PollableJobModel.count
      }.by(1)

      job          = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('app.delete')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(app_model.guid)
      expect(job.resource_type).to eq('app')

      expect(response.status).to eq(202)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end
  end

  describe '#start' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :start, guid: app_model.guid

      response_body = parsed_body

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['state']).to eq('STARTED')
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :start, guid: app_model.guid

          response_body = parsed_body
          expect(response_body['errors'].first['title']).to eq 'CF-NotAuthorized'
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
          expect(response_body['errors'].first['title']).to eq 'CF-ResourceNotFound'
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
          expect(response_body['errors'].first['title']).to eq 'CF-NotAuthorized'
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
        expect(response_body['errors'].first['title']).to eq 'CF-ResourceNotFound'
        expect(response.status).to eq 404
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :start, guid: 'meowmeowmeow'

        response_body = parsed_body
        expect(response_body['errors'].first['title']).to eq 'CF-ResourceNotFound'
        expect(response.status).to eq 404
      end
    end

    context 'when the user has an invalid app' do
      before do
        allow(VCAP::CloudController::AppStart).to receive(:start).
          and_raise(VCAP::CloudController::AppStart::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :start, guid: app_model.guid

        response_body = parsed_body
        expect(response_body['errors'].first['title']).to eq 'CF-UnprocessableEntity'
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
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :stop, guid: app_model.guid

      response_body = parsed_body

      expect(response.status).to eq 200
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['state']).to eq('STOPPED')
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
          allow_user_read_access_for(user, spaces: [space])
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
        allow(VCAP::CloudController::AppStop).
          to receive(:stop).and_raise(VCAP::CloudController::AppStop::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :stop, guid: app_model.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end
  end

  describe '#show_env' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { meep: 'moop', beep: 'boop' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the environment variables' do
      allow(controller).to receive(:can_see_secrets?).and_return(true)
      get :show_env, guid: app_model.guid

      expect(response.status).to eq 200
      expect(parsed_body['environment_variables']).to eq(app_model.environment_variables)
    end

    context 'permissions' do
      context 'when the user does not have read permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
        end

        it 'returns a 403' do
          get :show_env, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show_env, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when user can see secrets' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(true)
        end

        it 'succeeds' do
          get :show_env, guid: app_model.guid
          expect(response.status).to eq(200)
        end
      end

      context 'when user can not see secrets' do
        before do
          allow(controller).to receive(:can_see_secrets?).and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          get :show_env, guid: app_model.guid

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
          get :show_env, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('space_developer_env_var_visibility')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin(user: user)
          get :show_env, guid: app_model.guid

          expect(response.status).to eq(200)
        end

        it 'succeeds for admins_read_only' do
          set_current_user_as_admin_read_only(user: user)
          get :show_env, guid: app_model.guid

          expect(response.status).to eq(200)
        end

        context 'when user can not see secrets' do
          before do
            allow(controller).to receive(:can_see_secrets?).and_return(false)
          end

          it 'raises ApiError NotAuthorized as opposed to FeatureDisabled' do
            get :show_env, guid: app_model.guid

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
          get :show_env, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('Feature Disabled: env_var_visibility')
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show_env, guid: 'beep-boop'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#show_environment_variables' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { meep: 'moop', beep: 'boop' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_success_response) do
      {
        'var' => {
          'meep' => 'moop',
          'beep' => 'boop'
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          'app'  => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end

    before do
      set_current_user(user, scopes: ['cloud_controller.read'])
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'space_developer'     => 200,
        'org_manager'         => 403,
        'org_user'            => 404,
        'space_manager'       => 403,
        'space_auditor'       => 403,
        'org_auditor'         => 404,
        'org_billing_manager' => 404,
        'admin'               => 200,
        'admin_read_only'     => 200
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user, scopes: ['cloud_controller.read'])

            get :show_environment_variables, guid: app_model.guid

            expect(response.status).to eq expected_return_value
            if expected_return_value == 200
              expect(parsed_body).to eq(expected_success_response)
            end
          end
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        role_to_expected_http_response.merge({ 'space_developer' => 403 }).each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              get :show_environment_variables, guid: app_model.guid

              expect(response.status).to eq expected_return_value
              if role == 'space_developer'
                expect(response.body).to include('FeatureDisabled')
                expect(response.body).to include('space_developer_env_var_visibility')
              end
            end
          end
        end
      end

      context 'when the env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for all users' do
          set_current_user_as_admin(user: user)
          get :show_environment_variables, guid: app_model.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('Feature Disabled: env_var_visibility')
        end
      end
    end

    context 'when the user does not have read scope' do
      let(:user) { VCAP::CloudController::User.make }

      before do
        org.add_user(user)
        space.add_developer(user)
        set_current_user(user, scopes: [])
      end

      it 'returns a 403' do
        get :show_environment_variables, guid: app_model.guid

        expect(response.status).to eq 403
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show_environment_variables, guid: 'beep-boop'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the app does not have environment variables' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns 200 and the set of links' do
        set_current_user_as_admin(user: user)
        get :show_environment_variables, guid: app_model.guid

        expect(response.status).to eq(200)
        expect(parsed_body).to eq({
          'links' => expected_success_response['links'],
          'var'   => {},
        })
      end
    end
  end

  describe '#update_environment_variables' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { override: 'value-to-override', preserve: 'value-to-keep' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_success_response) do
      {
        'var' => {
          'override' => 'new-value',
          'preserve' => 'value-to-keep',
          'new-key'  => 'another-new-value'
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          'app'  => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end

    let(:request_body) do
      {
        'var' => {
          'override' => 'new-value',
          'new-key'  => 'another-new-value'
        }
      }
    end

    before do
      set_current_user(user)
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'space_developer'     => 200,
        'org_manager'         => 403,
        'org_user'            => 404,
        'space_manager'       => 403,
        'space_auditor'       => 403,
        'org_auditor'         => 404,
        'org_billing_manager' => 404,
        'admin'               => 200,
        'admin_read_only'     => 403
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            patch :update_environment_variables, guid: app_model.guid, body: request_body

            expect(response.status).to eq(expected_return_value), response.body
            if expected_return_value == 200
              expect(parsed_body).to eq(expected_success_response)

              app_model.reload
              expect(app_model.environment_variables).to eq({
                'override' => 'new-value',
                'preserve' => 'value-to-keep',
                'new-key'  => 'another-new-value',
              })
            end
          end
        end
      end
    end

    context 'when the given app does not exist' do
      before do
        set_current_user_as_admin(user: user)
      end

      it 'returns a validation error' do
        patch :update_environment_variables, guid: 'fake-guid', body: request_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when given an invalid request' do
      let(:request_body) do
        {
          'var' => {
            'PORT' => 8080
          }
        }
      end

      before do
        set_current_user_as_admin(user: user)
      end

      it 'returns a validation error' do
        patch :update_environment_variables, guid: app_model.guid, body: request_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'PORT'
      end
    end
  end

  describe '#assign_current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:req_body) { { data: { guid: droplet.guid } } }
    let(:droplet_link) { { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the droplet guid' do
      put :assign_current_droplet, guid: app_model.guid, body: req_body

      response_body = parsed_body

      expect(response.status).to eq(200)
      expect(response_body['data']['guid']).to eq(droplet.guid)
      expect(response_body['links']['related']).to eq(droplet_link)
    end

    context 'the user does not provide the data key' do
      let(:req_body) { {} }

      it 'returns a 422' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
      end
    end

    context 'the user does not provide any droplet guid element' do
      let(:req_body) { { data: nil } }

      it 'returns a 422' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Current droplet cannot be removed. Replace it with a preferred droplet.'
      end
    end

    context 'and the droplet is not associated with the application' do
      let(:unassociated_droplet) { VCAP::CloudController::DropletModel.make }
      let(:req_body) { { data: { guid: unassociated_droplet.guid } } }

      it 'returns a 422' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
      end
    end

    context 'and the droplet does not exist' do
      let(:req_body) { { data: { guid: 'pitter-patter-zim-zoom' } } }

      it 'returns a 422' do
        put :assign_current_droplet, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
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
        allow_any_instance_of(VCAP::CloudController::SetCurrentDroplet).to receive(:update_to).
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
          allow_user_read_access_for(user, spaces: [space])
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

  describe '#current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_link) { { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
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
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200 OK' do
          get :current_droplet, guid: app_model.guid

          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe '#current_droplet_relationship' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_link) { { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'returns a 200 OK and describes a droplet relationship' do
      get :current_droplet_relationship, guid: app_model.guid

      expect(response.status).to eq(200)
      expect(parsed_body['data']['guid']).to eq(droplet.guid)
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        get :current_droplet_relationship, guid: 'i do not exist'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the current droplet is not set' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns a 404 Not Found' do
        get :current_droplet_relationship, guid: app_model.guid

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
          get :current_droplet_relationship, guid: app_model.guid

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
          get :current_droplet_relationship, guid: app_model.guid

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not update the application' do
        let(:space) { droplet.space }
        let(:org) { space.organization }

        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200 OK' do
          get :current_droplet_relationship, guid: app_model.guid

          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe '#feature/' do
    let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:ssh_enabled) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => true } }
    let(:ssh_disabled) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => false } }
    role_to_expected_http_response = {
      'admin'               => 200,
      'admin_read_only'     => 200,
      'global_auditor'      => 200,
      'space_developer'     => 200,
      'space_manager'       => 200,
      'space_auditor'       => 200,
      'org_manager'         => 200,
      'org_auditor'         => 404,
      'org_billing_manager' => 404,
    }.freeze

    describe '#feature/ssh' do
      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value} for features/ssh" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :feature, guid: app_model.guid, name: 'ssh'

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            if expected_return_value == 200
              expect(parsed_body).to eq(ssh_enabled), "failed to match parsed_body for role #{role}: got #{parsed_body}"
            end
          end
        end
      end

      context 'enable_ssh is false' do
        let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: false) }

        it 'returns enabled false' do
          set_current_user_as_role(role: 'admin', org: nil, space: nil, user: user)
          get :feature, guid: app_model.guid, name: 'ssh'
          expect(parsed_body).to eq(ssh_disabled)
        end
      end
    end

    describe '#feature/404' do
      it 'throws 404 for a non-existent feature' do
        set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

        get :feature, guid: app_model.guid, name: 'i-dont-exist'

        expect(response.status).to eq(404)
      end
    end
  end

  describe '#features' do
    let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:ssh_enabled) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => true } }
    let(:ssh_disabled) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => false } }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin'               => 200,
        'admin_read_only'     => 200,
        'global_auditor'      => 200,
        'space_developer'     => 200,
        'space_manager'       => 200,
        'space_auditor'       => 200,
        'org_manager'         => 200,
        'org_auditor'         => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value} for list-features" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :features, guid: app_model.guid

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            if expected_return_value == 200
              expect(parsed_body).to eq(
                'resources'  => [ssh_enabled],
                'pagination' => {}
              ), "failed to match parsed_body for role #{role}: got #{parsed_body}"
            end
          end
        end
      end

      context 'enable_ssh is false' do
        let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: false) }

        it 'returns enabled false' do
          set_current_user_as_role(role: 'admin', org: nil, space: nil, user: user)
          get :features, guid: app_model.guid
          expect(parsed_body).to eq(
            'resources'  => [ssh_disabled],
            'pagination' => {}
          )
        end
      end
    end
  end
end
