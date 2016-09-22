require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:tasks_enabled) { true }
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }

  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end

    let(:req_body) do
      {
        "name": 'mytask',
        "command": 'rake db:migrate && true',
        "memory_in_mb": 2048,
        "environment_variables": {
          "unicorn": 'magic'
        }
      }
    end
    let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: tasks_enabled, error_message: nil)

      app_model.droplet = droplet
      app_model.save

      locator = CloudController::DependencyLocator.instance
      allow(locator).to receive(:nsync_client).and_return(client)
      allow(client).to receive(:desire_task).and_return(nil)
    end

    it 'returns a 202 and the task' do
      post :create, app_guid: app_model.guid, body: req_body

      expect(response.status).to eq 202
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['state']).to eq('PENDING')
      expect(parsed_body['memory_in_mb']).to eq(2048)
      expect(parsed_body['sequence_id']).to eq(1)
    end

    it 'creates a task for the app' do
      expect(app_model.tasks.count).to eq(0)

      post :create, app_guid: app_model.guid, body: req_body

      expect(app_model.reload.tasks.count).to eq(1)
      expect(app_model.tasks.first).to eq(VCAP::CloudController::TaskModel.last)
    end

    it 'passes user info to the task creator' do
      task = VCAP::CloudController::TaskModel.make
      task_create = instance_double(VCAP::CloudController::TaskCreate, create: task)
      allow(VCAP::CloudController::TaskCreate).to receive(:new).and_return(task_create)

      set_current_user(user, email: 'user-email')

      post :create, app_guid: app_model.guid, body: req_body

      expect(task_create).to have_received(:create).with(anything, anything, user.guid, 'user-email', droplet: nil)
    end

    context 'permissions' do
      context 'when the task_creation feature flag is disabled' do
        let(:tasks_enabled) { false }

        it 'raises 403 for non-admins' do
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('task_creation')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin(user: user)
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq(202)
        end
      end

      context 'when the user does not have write scope' do
        before do
          set_current_user(user, scopes: ['cloud_controller.read'])
        end

        it 'raises 403' do
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write permissions on the app space' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403 unauthorized' do
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'when the app does not exist' do
      it 'returns a 404 ResourceNotFound' do
        post :create, app_guid: 'bogus', body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user has requested an invalid field' do
      it 'returns a 400 and a helpful error' do
        req_body[:invalid] = 'field'

        post :create, app_guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unknown field(s): 'invalid'"
      end
    end

    context 'when there is a validation failure' do
      it 'returns a 422 and a helpful error' do
        stub_const('VCAP::CloudController::TaskModel::COMMAND_MAX_LENGTH', 6)
        req_body[:command] = 'a' * 7

        post :create, app_guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'The request is semantically invalid: command must be shorter than 7 characters'
      end
    end

    context 'invalid task' do
      it 'returns a useful error message' do
        post :create, app_guid: app_model.guid, body: {}

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    describe 'droplets' do
      context 'when a droplet guid is not provided' do
        it "successfully creates the task on the app's droplet" do
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq(202)
          expect(parsed_body['droplet_guid']).to include(droplet.guid)
        end

        context 'and the app does not have an assigned droplet' do
          let(:droplet) { nil }

          it 'returns a 422 and a helpful error' do
            post :create, app_guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'Task must have a droplet. Specify droplet or assign current droplet to app.'
          end
        end
      end

      context 'when a custom droplet guid is provided' do
        let(:custom_droplet) {
          VCAP::CloudController::DropletModel.make(app_guid: app_model.guid,
                                                   state: VCAP::CloudController::DropletModel::STAGED_STATE)
        }

        it 'successfully creates a task on the specifed droplet' do
          post :create, app_guid: app_model.guid, body: {
            "name": 'mytask',
            "command": 'rake db:migrate && true',
            "droplet_guid": custom_droplet.guid
          }

          expect(response.status).to eq 202
          expect(parsed_body['droplet_guid']).to eq(custom_droplet.guid)
          expect(parsed_body['droplet_guid']).to_not eq(droplet.guid)
        end

        context 'and the droplet is not found' do
          it 'returns a 404' do
            post :create, app_guid: app_model.guid, body: {
              "name": 'mytask',
              "command": 'rake db:migrate && true',
              "droplet_guid": 'fake-droplet-guid'
            }

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Droplet not found'
          end
        end

        context 'and the droplet does not belong to the app' do
          let(:custom_droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }

          it 'returns a 404' do
            post :create, app_guid: app_model.guid, body: {
              "name": 'mytask',
              "command": 'rake db:migrate && true',
              "droplet_guid": custom_droplet.guid
            }

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Droplet not found'
          end
        end
      end
    end
  end

  describe '#show' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'mytask', app_guid: app_model.guid, memory_in_mb: 2048 }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_secret_access(user, space: space)
    end

    it 'returns a 200 and the task' do
      get :show, task_guid: task.guid

      expect(response.status).to eq 200
      expect(parsed_body['name']).to eq('mytask')
      expect(parsed_body['memory_in_mb']).to eq(2048)
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'raises 403' do
          get :show, task_guid: task.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          get :show, task_guid: task.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end

      context 'when the user has read, but not write permissions on the app space' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 200' do
          get :show, task_guid: task.guid

          expect(response.status).to eq 200
        end
      end
    end

    it 'returns a 404 if the task does not exist' do
      get :show, task_guid: 'bogus'

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'Task not found'
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      stub_readable_space_guids_for(user, space)
    end

    it 'returns tasks the user has read access' do
      task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
      VCAP::CloudController::TaskModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([task_1.guid, task_2.guid])
    end

    it 'provides the correct base url in the pagination links' do
      get :index

      expect(parsed_body['pagination']['first']['href']).to include('/v3/tasks')
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)

        get :index, params

        parsed_response = parsed_body
        response_guids = parsed_response['resources'].map { |r| r['guid'] }
        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(response_guids.length).to eq(per_page)
      end
    end

    context 'when accessed as an app subresource' do
      before do
        allow_user_secret_access(user, space: space)
      end

      it 'uses the app as a filter' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        VCAP::CloudController::TaskModel.make

        get :index, app_guid: app_model.guid

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([task_1.guid, task_2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app_model.guid

        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app_model.guid}/tasks")
      end

      context 'when the user cannot view secrets' do
        before do
          disallow_user_secret_access(user, space: space)
        end

        it 'excludes secrets' do
          VCAP::CloudController::TaskModel.make(app: app_model)

          get :index, app_guid: app_model.guid

          expect(parsed_body['resources'][0]).not_to have_key('command')
        end
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, app_guid: 'hello-i-do-not-exist'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: app_model.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when space_guids, org_guids, or app_guids are present' do
        it 'returns a 400 Bad Request' do
          get :index, { app_guid: app_model.guid, 'space_guids' => [app_model.space.guid], 'organization_guids' => [app_model.organization.guid], 'app_guids' => [app_model.guid] }

          expect(response.status).to eq 400
          expect(response.body).to include "Unknown query parameter(s): 'space_guids', 'organization_guids', 'app_guids'"
        end
      end
    end

    context 'admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns a 200 and all tasks' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_3 = VCAP::CloudController::TaskModel.make

        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([task_1, task_2, task_3].map(&:guid))
      end
    end

    context 'admin read only' do
      before do
        set_current_user_as_admin_read_only
      end

      it 'returns a 200 and all tasks' do
        task_1 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_2 = VCAP::CloudController::TaskModel.make(app_guid: app_model.guid)
        task_3 = VCAP::CloudController::TaskModel.make

        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([task_1, task_2, task_3].map(&:guid))
      end
    end

    describe 'query params errors' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, per_page: 'meow'

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, meow: 'bad-val', nyan: 'mow'

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end
  end

  describe '#cancel' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'usher', app_guid: app_model.guid }
    let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      locator = CloudController::DependencyLocator.instance
      allow(locator).to receive(:nsync_client).and_return(client)
      allow(client).to receive(:cancel_task).and_return(nil)
    end

    it 'returns a 202' do
      put :cancel, task_guid: task.guid

      expect(response.status).to eq 202
      expect(parsed_body['name']).to eq('usher')
      expect(parsed_body['guid']).to eq(task.guid)
    end

    context 'when the task does not exist' do
      it 'returns a 404 ResourceNotFound' do
        put :cancel, task_guid: 'bogus-guid'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Task not found'
      end
    end

    context 'when InvalidCancel is raised' do
      before do
        allow_any_instance_of(VCAP::CloudController::TaskCancel).to receive(:cancel).and_raise(VCAP::CloudController::TaskCancel::InvalidCancel.new('sad trombone'))
      end

      it 'returns a 422 Unprocessable' do
        put :cancel, task_guid: task.guid

        expect(response.status).to eq 422
        expect(response.body).to include('sad trombone')
      end
    end

    context 'permissions' do
      context 'when the user does not have read permissions on the app space' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound' do
          put :cancel, task_guid: task.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
        end
      end

      context 'when the user has read, but not write permissions on the app space' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 403 NotAuthorized' do
          put :cancel, task_guid: task.guid

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end
end
