require 'rails_helper'

RSpec.describe ProcessesController, type: :controller do
  let(:space) { VCAP::CloudController::Space.make }

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      stub_readable_space_guids_for(user, space)
      allow_user_read_access(user, space: space)
    end

    it 'returns 200 and lists the processes' do
      process1 = VCAP::CloudController::ProcessModel.make(space: space)
      process2 = VCAP::CloudController::ProcessModel.make(space: space)
      VCAP::CloudController::ProcessModel.make

      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([process1.guid, process2.guid])
    end

    context 'when accessed as an app subresource' do
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }

      it 'uses the app as a filter' do
        process1 = VCAP::CloudController::ProcessModel.make(app_guid: app.guid)
        process2 = VCAP::CloudController::ProcessModel.make(app_guid: app.guid)
        VCAP::CloudController::ProcessModel.make

        get :index, app_guid: app.guid

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([process1.guid, process2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app.guid
        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app.guid}/processes")
      end

      context 'when pagination options are specified' do
        let(:page) { 1 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page, app_guid: app.guid } }

        it 'paginates the response' do
          VCAP::CloudController::ProcessModel.make(app_guid: app.guid)
          VCAP::CloudController::ProcessModel.make(app_guid: app.guid)

          get :index, params

          parsed_response = parsed_body
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(response_guids.length).to eq(per_page)
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
          get :index, app_guid: app.guid

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
      let!(:process1) { VCAP::CloudController::ProcessModel.make(space: space) }
      let!(:process2) { VCAP::CloudController::ProcessModel.make(space: space) }
      let!(:process3) { VCAP::CloudController::ProcessModel.make }

      context 'admin' do
        before { set_current_user_as_admin }

        it 'returns 200 and lists all processes' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids).to match_array([process1.guid, process2.guid, process3.guid])
        end
      end

      context 'read only admin' do
        before { set_current_user_as_admin_read_only }

        it 'returns 200 and lists all processes' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids).to match_array([process1.guid, process2.guid, process3.guid])
        end
      end
    end
    context 'when the request parameters are invalid' do
      context 'because there are unknown parameters' do
        let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include("Unknown query parameter(s): 'invalid', 'bad'")
        end
      end

      context 'because of order_by' do
        it 'returns 400' do
          get :index, order_by: '^=%'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
        end
      end

      context 'because there are invalid values in parameters' do
        let(:params) { { 'per_page' => 10000 } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between 1 and 5000')
        end
      end
    end
  end

  describe '#show' do
    let(:process_type) { VCAP::CloudController::App.make(space: space) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 OK with process' do
      get :show, { process_guid: process_type.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    context 'accessed as an app sub resource' do
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }
      let(:process_type) { VCAP::CloudController::App.make(app_guid: app.guid, type: 'web') }
      let!(:process_type2) { VCAP::CloudController::App.make(app_guid: app.guid, type: 'worker') }

      it 'returns a 200 and the process' do
        get :show, type: process_type.type, app_guid: app.guid

        expect(response.status).to eq 200
        expect(parsed_body['guid']).to eq(process_type.guid)
      end

      context 'when the requested process does not belong to the provided app guid' do
        it 'returns a 404' do
          other_app = VCAP::CloudController::AppModel.make
          other_process = VCAP::CloudController::App.make(app_guid: other_app.guid, type: 'potato')

          get :show, type: other_process.type, app_guid: app.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Process not found'
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404' do
          get :show, type: process_type.type, app_guid: 'made-up'

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
          get :show, type: process_type.type, app_guid: app.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, { process_guid: 'ABC123' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')
      end
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before { set_current_user(user, scopes: []) }

        it 'raises an ApiError with a 403 code' do
          get :show, { process_guid: process_type.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          get :show, { process_guid: process_type.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('Process not found')
        end
      end
    end
  end

  describe '#update' do
    let(:process_type) { VCAP::CloudController::App.make(:process, space: space) }
    let(:req_body) do
      {
          'command' => 'new command',
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'updates the process and returns the correct things' do
      expect(process_type.command).not_to eq('new command')

      patch :update, req_body.to_json, { process_guid: process_type.guid }

      expect(process_type.reload.command).to eq('new command')
      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    context 'when the provided request to update the port is an empty array' do
      it 'update the model successfully' do
        patch :update, { ports: [], health_check: { type: 'process' } }.to_json, { process_guid: process_type.guid, type: :json }

        expect(parsed_body['ports']).to eq([])
        expect(process_type.reload.ports).to eq([])
        expect(response.status).to eq(200)
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        patch :update, req_body.to_json, { process_guid: 'made-up-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessUpdate).to receive(:update).and_raise(VCAP::CloudController::ProcessUpdate::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        patch :update, req_body.to_json, { process_guid: process_type.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when the request provides invalid data' do
      let(:req_body) { { command: false } }

      it 'returns 422' do
        patch :update, req_body.to_json, { process_guid: process_type.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Command must be a string')
      end
    end

    context 'permissions' do
      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          patch :update, req_body.to_json, { process_guid: process_type.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          patch :update, req_body.to_json, { process_guid: process_type.guid }

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user does not have write permissions' do
        before { set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          patch :update, req_body.to_json, { process_guid: process_type.guid }

          expect(response.body).to include('NotAuthorized')
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe '#terminate' do
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::AppFactory.make(app: app, space: space) }
    let(:index_stopper) { instance_double(VCAP::CloudController::IndexStopper) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow(index_stopper).to receive(:stop_index)
      allow(CloudController::DependencyLocator.instance).to receive(:index_stopper).and_return(index_stopper)
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'terminates the process instance' do
      expect(process_type.instances).to eq(1)

      delete :terminate, { process_guid: process_type.guid, index: 0 }
      expect(response.status).to eq(204)

      process_type.reload
      expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
    end

    context 'accessed as an app subresource' do
      it 'terminates the process instance' do
        expect(process_type.instances).to eq(1)

        delete :terminate, app_guid: app.guid, type: process_type.type, index: 0

        expect(response.status).to eq(204)
        expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
      end

      it 'returns a 404 if app does not exist' do
        delete :terminate, app_guid: 'sad-bad-guid', type: process_type.type, index: 0

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end

      it 'returns a 404 if process type does not exist' do
        delete :terminate, app_guid: app.guid, type: 'bad-type', index: 0

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          delete :terminate, app_guid: app.guid, type: process_type.type, index: 0

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App not found'
        end
      end
    end

    it 'returns a 404 if process does not exist' do
      delete :terminate, { process_guid: 'bad-guid', index: 0 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Process not found')
    end

    it 'returns a 404 if instance index out of bounds' do
      delete :terminate, { process_guid: process_type.guid, index: 1 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Instance not found')
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before { set_current_user(user, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          delete :terminate, { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          delete :terminate, { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          delete :terminate, { process_guid: process_type.guid, index: 0 }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#scale' do
    let(:req_body) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::App.make(app: app, space: space) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'scales the process and returns the correct things' do
      expect(process_type.instances).not_to eq(2)
      expect(process_type.memory).not_to eq(100)
      expect(process_type.disk_quota).not_to eq(200)

      put :scale, { process_guid: process_type.guid, body: req_body }

      process_type.reload
      expect(process_type.instances).to eq(2)
      expect(process_type.memory).to eq(100)
      expect(process_type.disk_quota).to eq(200)
      expect(response.status).to eq(202)
      expect(parsed_body['guid']).to eq(process_type.guid)
    end

    context 'accessed as app subresource' do
      it 'scales the process and returns the correct things' do
        expect(process_type.instances).not_to eq(2)
        expect(process_type.memory).not_to eq(100)
        expect(process_type.disk_quota).not_to eq(200)

        put :scale, app_guid: app.guid, type: process_type.type, body: req_body

        process_type.reload
        expect(process_type.instances).to eq(2)
        expect(process_type.memory).to eq(100)
        expect(process_type.disk_quota).to eq(200)

        expect(response.status).to eq(202)
        expect(parsed_body['guid']).to eq(process_type.guid)
      end

      context 'when the app does not exist' do
        it 'raises 404' do
          put :scale, app_guid: 'foo', type: process_type.type

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include('App not found')
        end
      end

      context 'when the process does not exist' do
        it 'raises 404' do
          put :scale, app_guid: app.guid, type: 'bananas'

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
          put :scale, app_guid: app.guid, type: process_type.type

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'App'
        end
      end

      context 'when the user can read but not write to the process due to membership' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          put :scale, app_guid: app.guid, type: process_type.type

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
        put :scale, { process_guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when scaling is disabled' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

      context 'non-admin user' do
        it 'raises 403' do
          put :scale, { process_guid: process_type.guid, body: req_body }

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('app_scaling')
        end
      end
    end

    context 'when the user does not have write permissions' do
      before { set_current_user(user, scopes: ['cloud_controller.read']) }

      it 'raises an ApiError with a 403 code' do
        put :scale, { process_guid: process_type.guid, body: req_body }

        expect(response.status).to eq 403
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the request provides invalid data' do
      let(:req_body) { { instances: 'wrong' } }

      it 'returns 422' do
        put :scale, { process_guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Instances is not a number')
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        put :scale, { process_guid: 'fake-guid', body: req_body }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          put :scale, { process_guid: process_type.guid, body: req_body }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the process' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises an ApiError with a 403 code' do
          put :scale, { process_guid: process_type.guid, body: req_body }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user does not have write permissions' do
        before { set_current_user(user, scopes: ['cloud_controller.read']) }

        it 'raises an ApiError with a 403 code' do
          put :scale, { process_guid: process_type.guid, body: req_body }

          expect(response.status).to eq 403
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#stats' do
    let(:app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:process_type) { VCAP::CloudController::AppFactory.make(diego: true, type: 'potato', app_guid: app.guid, space: space) }
    let(:stats) { { 0 => { stats: { usage: {}, net_info: { ports: [] } } } } }
    let(:instances_reporters) { double(:instances_reporters) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: space)
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      allow(instances_reporters).to receive(:stats_for_app).and_return(stats)
    end

    it 'returns the stats for all instances for the process' do
      put :stats, { process_guid: process_type.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['resources'][0]['type']).to eq('potato')
    end

    context 'accessed as app subresource' do
      it 'returns the stats for all instances of specified type for all processes of an app' do
        put :stats, { app_guid: app.guid, type: process_type.type }

        expect(response.status).to eq(200)
        expect(parsed_body['resources'][0]['type']).to eq('potato')
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404 error' do
          put :stats, { app_guid: app.guid, type: process_type.type }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('App')
        end
      end

      context 'when the app does not exist' do
        it 'raises a 404 error' do
          put :stats, { app_guid: 'bogus-guid', type: process_type.type }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('App')
        end
      end

      context 'when process does not exist' do
        it 'raises a 404 error' do
          put :stats, { app_guid: app.guid, type: 1234 }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
          expect(response.body).to include('Process')
        end
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        get :stats, { process_guid: 'fake-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have read scope' do
        before { set_current_user(user, scopes: ['cloud_controller.write']) }

        it 'raises an ApiError with a 403 code' do
          put :stats, { process_guid: process_type.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the process' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'raises 404' do
          put :stats, { process_guid: process_type.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end
  end
end
