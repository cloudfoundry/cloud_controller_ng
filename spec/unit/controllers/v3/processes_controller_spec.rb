require 'rails_helper'

RSpec.describe ProcessesController, type: :controller do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app) { VCAP::CloudController::AppModel.make(space: space) }

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'returns 200 and lists the processes' do
      process1 = VCAP::CloudController::ProcessModel.make(:process, app: app)
      process2 = VCAP::CloudController::ProcessModel.make(:process, app: app)
      VCAP::CloudController::ProcessModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([process1.guid, process2.guid])
    end

    context 'when accessed as an app subresource' do
      it 'uses the app as a filter' do
        process1 = VCAP::CloudController::ProcessModel.make(:process, app: app)
        process2 = VCAP::CloudController::ProcessModel.make(:process, app: app)
        VCAP::CloudController::ProcessModel.make(:process)

        get :index, params: { app_guid: app.guid }

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([process1.guid, process2.guid])
      end

      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::ProcessListFetcher).to receive(:fetch_for_app).with(
          an_instance_of(VCAP::CloudController::ProcessesListMessage),
          hash_including(eager_loaded_associations: [:labels, :annotations])
        ).and_call_original

        get :index, params: { app_guid: app.guid }

        expect(response.status).to eq(200)
      end

      it 'provides the correct base url in the pagination links' do
        get :index, params: { app_guid: app.guid }
        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app.guid}/processes")
      end

      context 'when pagination options are specified' do
        let(:page) { 1 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page, app_guid: app.guid } }

        it 'paginates the response' do
          VCAP::CloudController::ProcessModel.make(:process, app: app)
          VCAP::CloudController::ProcessModel.make(:process, app: app)

          get :index, params: params

          parsed_response = parsed_body
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(response_guids.length).to eq(per_page)
        end
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, params: { app_guid: 'hello-i-do-not-exist' }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, params: { app_guid: app.guid }

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user does not have read scope' do
      before do
        set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
      end

      it 'returns 403 NotAuthorized' do
        get :index

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'admin types' do
      let!(:process1) { VCAP::CloudController::ProcessModel.make(app: app, type: 'salt') }
      let!(:process2) { VCAP::CloudController::ProcessModel.make(app: app, type: 'peppa') }
      let!(:process3) { VCAP::CloudController::ProcessModel.make }

      context 'when the user has global read access' do
        before { allow_user_global_read_access(user) }

        it 'returns 200 and lists all processes' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids).to match_array([process1.guid, process2.guid, process3.guid])
        end

        it 'eager loads associated resources that the presenter specifies' do
          expect(VCAP::CloudController::ProcessListFetcher).to receive(:fetch_all).with(
            an_instance_of(VCAP::CloudController::ProcessesListMessage),
            hash_including(eager_loaded_associations: [:labels, :annotations])
          ).and_call_original

          get :index

          expect(response.status).to eq(200)
        end
      end
    end

    context 'when the request parameters are invalid' do
      context 'because there are unknown parameters' do
        let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

        it 'returns an 400 Bad Request' do
          get :index, params: params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s):')
          expect(response.body).to include('invalid')
          expect(response.body).to include('bad')
        end
      end

      context 'because of order_by' do
        it 'returns 400' do
          get :index, params: { order_by: '^=%' }

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
        end
      end

      context 'because there are invalid values in parameters' do
        let(:params) { { 'per_page' => 10000 } }

        it 'returns an 400 Bad Request' do
          get :index, params: params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between 1 and 5000')
        end
      end
    end
  end

  describe '#show' do
    let(:process_type) { VCAP::CloudController::ProcessModel.make(app: app) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 OK with process' do
      get :show, params: { process_guid: process_type.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    context 'accessed as an app sub resource' do
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:process_type) { VCAP::CloudController::ProcessModel.make(:process, app: app) }
      let!(:process_type2) { VCAP::CloudController::ProcessModel.make(:process, app: app) }

      it 'returns a 200 and the process' do
        get :show, params: { type: process_type.type, app_guid: app.guid }

        expect(response.status).to eq 200
        expect(parsed_body['guid']).to eq(process_type.guid)
      end

      context 'when the requested process does not belong to the provided app guid' do
        it 'returns a 404' do
          other_app = VCAP::CloudController::AppModel.make
          other_process = VCAP::CloudController::ProcessModel.make(app: other_app, type: 'potato')

          get :show, params: { type: other_process.type, app_guid: app.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Process not found'
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404' do
          get :show, params: { type: process_type.type, app_guid: 'made-up' }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end

      context 'when the user cannot read the app due to membership' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404' do
          get :show, params: { type: process_type.type, app_guid: app.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, params: { process_guid: 'ABC123' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')
      end
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before { set_current_user(user, scopes: []) }

        it 'raises an ApiError with a 403 code' do
          get :show, params: { process_guid: process_type.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          get :show, params: { process_guid: process_type.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('Process not found')
        end
      end
    end
  end

  describe '#update' do
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::ProcessModel.make(:process, app: app) }
    let(:request_body) do
      {
          'command' => 'new command',
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'updates the process and returns the correct things' do
      expect(process_type.command).not_to eq('new command')

      patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

      expect(process_type.reload.command).to eq('new command')
      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    context 'accessed as an app sub resource' do
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:process_type) { VCAP::CloudController::ProcessModel.make(:process, app: app) }
      let!(:process_type2) { VCAP::CloudController::ProcessModel.make(:process, app: app) }

      it 'updates the process and returns the correct things' do
        expect(process_type.command).not_to eq('new command')

        patch :update, params: { app_guid: app.guid, type: process_type.type }.merge(request_body), as: :json

        expect(process_type.reload.command).to eq('new command')
        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(process_type.guid)
      end

      context 'when the requested process does not belong to the provided app guid' do
        it 'returns a 404' do
          other_app = VCAP::CloudController::AppModel.make
          other_process = VCAP::CloudController::ProcessModel.make(app: other_app, type: 'potato')

          patch :update, params: { app_guid: app.guid, type: other_process.type }.merge(request_body), as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Process not found'
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404' do
          patch :update, params: { app_guid: 'made-up', type: process_type.type }.merge(request_body), as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end

      context 'when the user cannot read the app due to membership' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404' do
          patch :update, params: { app_guid: app.guid, type: process_type.type }.merge(request_body), as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        patch :update, params: { process_guid: 'made-up-guid' }.merge(request_body), as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessUpdate).to receive(:update).and_raise(VCAP::CloudController::ProcessUpdate::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when the request provides invalid data' do
      let(:request_body) { { command: false } }

      it 'returns 422' do
        patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Command must be a string')
      end
    end

    context 'when the app is being deployed' do
      before do
        VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app)
      end

      it 'succeeds if the process is not a web process' do
        process = VCAP::CloudController::ProcessModel.make(:process, app: app, type: 'worker')

        patch :update, params: { process_guid: process.guid }.merge(request_body), as: :json

        expect(response.status).to eq(200)
      end

      it 'raises 422 if the process is a web process' do
        process = VCAP::CloudController::ProcessModel.make(:process, app: app, type: 'web')

        patch :update, params: { process_guid: process.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('Cannot update this process while a deployment is in flight.')
      end
    end

    context 'permissions' do
      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user does not have write permissions' do
        before { set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          patch :update, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.body).to include('NotAuthorized')
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe '#terminate' do
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::ProcessModel.make(app: app) }
    let(:index_stopper) { instance_double(VCAP::CloudController::IndexStopper) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow(index_stopper).to receive(:stop_index)
      allow(CloudController::DependencyLocator.instance).to receive(:index_stopper).and_return(index_stopper)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'terminates the process instance' do
      expect(process_type.instances).to eq(1)

      delete :terminate, params: { process_guid: process_type.guid, index: 0 }
      expect(response.status).to eq(204)

      process_type.reload
      expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
    end

    context 'accessed as an app subresource' do
      it 'terminates the process instance' do
        expect(process_type.instances).to eq(1)

        delete :terminate, params: { app_guid: app.guid, type: process_type.type, index: 0 }, as: :json

        expect(response.status).to eq(204)
        expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
      end

      it 'returns a 404 if app does not exist' do
        delete :terminate, params: { app_guid: 'sad-bad-guid', type: process_type.type, index: 0 }, as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end

      it 'returns a 404 if process type does not exist' do
        delete :terminate, params: { app_guid: app.guid, type: 'bad-type', index: 0 }, as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          delete :terminate, params: { app_guid: app.guid, type: process_type.type, index: 0 }, as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end
    end

    it 'returns a 404 if process does not exist' do
      delete :terminate, params: { process_guid: 'bad-guid', index: 0 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Process not found')
    end

    it 'returns a 404 if instance index out of bounds' do
      delete :terminate, params: { process_guid: process_type.guid, index: 1 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Instance not found')
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before { set_current_user(user, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          delete :terminate, params: { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          delete :terminate, params: { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          delete :terminate, params: { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#scale' do
    let(:request_body) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::ProcessModel.make(app: app) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    it 'scales the process and returns the correct things' do
      expect(process_type.instances).not_to eq(2)
      expect(process_type.memory).not_to eq(100)
      expect(process_type.disk_quota).not_to eq(200)

      put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

      process_type.reload
      expect(process_type.instances).to eq(2)
      expect(process_type.memory).to eq(100)
      expect(process_type.disk_quota).to eq(200)
      expect(response.status).to eq(202)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    it 'does not changes its version' do
      process_type.update(state: VCAP::CloudController::ProcessModel::STARTED)
      version = process_type.version
      put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

      expect(response.status).to eq(202)
      process_type.reload
      expect(process_type.version).to eq(version)
    end

    context 'accessed as app subresource' do
      it 'scales the process and returns the correct things' do
        expect(process_type.instances).not_to eq(2)
        expect(process_type.memory).not_to eq(100)
        expect(process_type.disk_quota).not_to eq(200)

        put :scale, params: { app_guid: app.guid, type: process_type.type }.merge(request_body), as: :json

        process_type.reload
        expect(process_type.instances).to eq(2)
        expect(process_type.memory).to eq(100)
        expect(process_type.disk_quota).to eq(200)

        expect(response.status).to eq(202)
        expect(parsed_body['guid']).to eq(process_type.guid)
      end

      context 'when the app does not exist' do
        it 'raises 404' do
          put :scale, params: { app_guid: 'foo', type: process_type.type }, as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include('App not found')
        end
      end

      context 'when the process does not exist' do
        it 'raises 404' do
          put :scale, params: { app_guid: app.guid, type: 'bananas' }, as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Process not found'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          put :scale, params: { app_guid: app.guid, type: process_type.type }, as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App'
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          put :scale, params: { app_guid: app.guid, type: process_type.type }, as: :json

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessScale).to receive(:scale).and_raise(VCAP::CloudController::ProcessScale::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when scaling is disabled' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

      context 'non-admin user' do
        it 'raises 403' do
          put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('app_scaling')
        end
      end
    end

    context 'when the user does not have write permissions' do
      before { set_current_user(user, scopes: ['cloud_controller.read']) }

      it 'raises an ApiError with a 403 code' do
        put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

        expect(response.status).to eq 403
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the request provides invalid data' do
      let(:request_body) { { instances: 'wrong' } }

      it 'returns 422' do
        put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Instances is not a number')
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        put :scale, params: { process_guid: 'fake-guid' }.merge(request_body), as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the app is being deployed' do
      before do
        VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app)
      end

      it 'succeeds if the process is not a web process' do
        process = VCAP::CloudController::ProcessModel.make(:process, app: app, type: 'worker')

        put :scale, params: { process_guid: process.guid }.merge(request_body), as: :json

        expect(response.status).to eq(202)
      end

      it 'raises 422 if the process is a web process' do
        process = VCAP::CloudController::ProcessModel.make(:process, app: app, type: 'web')

        put :scale, params: { process_guid: process.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('Cannot scale this process while a deployment is in flight.'), response.body
      end
    end

    context 'permissions' do
      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the process' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user does not have write permissions' do
        before { set_current_user(user, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          put :scale, params: { process_guid: process_type.guid }.merge(request_body), as: :json

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#stats' do
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::ProcessModel.make(:process, type: 'potato', app: app) }
    let(:stats) { { 0 => { stats: { usage: {}, net_info: { ports: [] } } } } }
    let(:instances_reporters) { double(:instances_reporters) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      allow(instances_reporters).to receive(:stats_for_app).and_return(stats)
    end

    it 'returns the stats for all instances for the process' do
      get :stats, params: { process_guid: process_type.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['resources'][0]['type']).to eq('potato')
    end

    context 'accessed as app subresource' do
      it 'returns the stats for all instances of specified type for all processes of an app' do
        get :stats, params: { app_guid: app.guid, type: process_type.type }

        expect(response.status).to eq(200)
        expect(parsed_body['resources'][0]['type']).to eq('potato')
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404 error' do
          get :stats, params: { app_guid: app.guid, type: process_type.type }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('App')
        end
      end

      context 'when the app does not exist' do
        it 'raises a 404 error' do
          get :stats, params: { app_guid: 'bogus-guid', type: process_type.type }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('App')
        end
      end

      context 'when process does not exist' do
        it 'raises a 404 error' do
          get :stats, params: { app_guid: app.guid, type: 1234 }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('Process')
        end
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        get :stats, params: { process_guid: 'fake-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before { set_current_user(user, scopes: ['cloud_controller.write']) }

        it 'raises an ApiError with a 403 code' do
          get :stats, params: { process_guid: process_type.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          get :stats, params: { process_guid: process_type.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end
  end
end
