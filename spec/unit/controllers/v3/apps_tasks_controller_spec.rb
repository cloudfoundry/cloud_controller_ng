require 'rails_helper'

describe AppsTasksController, type: :controller do
  let(:enabled) { true }
  let(:membership) { instance_double(VCAP::CloudController::Membership) }
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }

  before do
    VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: enabled, error_message: nil)
    @request.env.merge!(headers_for(VCAP::CloudController::User.make))
    allow_any_instance_of(AppsTasksController).to receive(:membership).and_return(membership)
    allow(membership).to receive(:has_any_roles?).with(
        [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(true)
    allow(membership).to receive(:has_any_roles?).with(
        [VCAP::CloudController::Membership::SPACE_DEVELOPER,
         VCAP::CloudController::Membership::SPACE_MANAGER,
         VCAP::CloudController::Membership::SPACE_AUDITOR,
         VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
  end

  describe '#create' do
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end
    let(:req_body) do
      {
        "name": 'mytask',
        "command": 'rake db:migrate && true',
      }
    end

    before do
      app_model.droplet = droplet
      app_model.save
    end

    it 'returns a 202 and the task' do
      post :create, guid: app_model.guid, body: req_body

      expect(response.status).to eq 202
      expect(JSON.parse(response.body)).to include('name' => 'mytask')
    end

    it 'creates a task for the app' do
      expect(app_model.tasks.count).to eq(0)

      post :create, guid: app_model.guid, body: req_body

      expect(app_model.reload.tasks.count).to eq(1)
      expect(app_model.tasks.first).to eq(VCAP::CloudController::TaskModel.last)
    end

    describe 'access permissions' do
      context 'when the task_creation feature flag is disabled' do
        let(:enabled) { false }

        it 'raises 403' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('task_creation')
        end
      end

      context 'when the user does not have write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'raises 403' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have write permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
              [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
          allow(membership).to receive(:has_any_roles?).with(
              [VCAP::CloudController::Membership::SPACE_DEVELOPER,
               VCAP::CloudController::Membership::SPACE_MANAGER,
               VCAP::CloudController::Membership::SPACE_AUDITOR,
               VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        end

        it 'returns a 403 unauthorized' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
              [VCAP::CloudController::Membership::SPACE_DEVELOPER,
               VCAP::CloudController::Membership::SPACE_MANAGER,
               VCAP::CloudController::Membership::SPACE_AUDITOR,
               VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'when the app does not exist' do
      it 'returns a 404 ResourceNotFound' do
        post :create, guid: 'bogus', body: req_body

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the app does not have an assigned droplet' do
      let(:droplet) { nil }

      it 'returns a 422 and a helpful error' do
        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Task must have a droplet. Specify droplet or assign current droplet to app.'
      end
    end

    context 'when the user has requested an invalid field' do
      it 'returns a 400 and a helpful error' do
        req_body.merge! invalid: 'field'

        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unknown field(s): 'invalid'"
      end
    end

    context 'invalid task' do
      it 'returns a useful error message' do
        post :create, guid: app_model.guid, body: {}

        expect(response.status).to eq 422
      end
    end
  end

  describe '#show' do
    let!(:task) { VCAP::CloudController::TaskModel.make name: 'mytask', app_guid: app_model.guid }

    it 'returns a 200 and the task' do
      get :show, task_guid: task.guid, app_guid: app_model.guid

      expect(response.status).to eq 200
      expect(JSON.parse(response.body)).to include('name' => 'mytask')
    end

    context 'when the requested task does not belong to the provided app guid' do
      it 'returns a 404' do
        other_app = VCAP::CloudController::AppModel.make space_guid: space.guid
        other_task = VCAP::CloudController::TaskModel.make name: 'other_task', app_guid: other_app.guid
        get :show, task_guid: other_task.guid, app_guid: app_model.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Task not found'
      end
    end

    context 'when only task guid is present' do
      it 'returns a 200 and the task' do
        get :show, task_guid: task.guid

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)).to include('name' => 'mytask')
      end
    end

    describe 'access permissions' do
      context 'when the user does not have read scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: [])))
        end

        it 'raises 403' do
          get :show, task_guid: task.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have read permissions on the app space' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
              [VCAP::CloudController::Membership::SPACE_DEVELOPER,
               VCAP::CloudController::Membership::SPACE_MANAGER,
               VCAP::CloudController::Membership::SPACE_AUDITOR,
               VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound' do
          get :show, task_guid: task.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Task not found'
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
end
