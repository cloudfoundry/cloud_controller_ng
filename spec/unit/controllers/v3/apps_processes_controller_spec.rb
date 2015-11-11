require 'rails_helper'

describe AppsProcessesController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  before do
    allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
    allow(membership).to receive(:has_any_roles?).and_return(true)
  end

  describe '#index' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:app_1) { VCAP::CloudController::App.make(space: space) }
    let(:app_2) { VCAP::CloudController::App.make(space: space) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      app_model.add_process(app_1)
      app_model.add_process(app_2)
      VCAP::CloudController::App.make
      VCAP::CloudController::App.make
    end

    it 'returns a 200 and presents the response' do
      get :index, guid: app_model.guid

      expect(response.status).to eq 200

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([app_1, app_2].map(&:guid))
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 and presents the response' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 200

        response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([app_1, app_2].map(&:guid))
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'raises an ApiError with a 403 code' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :index, guid: 'bogus'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
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
        get :index, guid: app_model.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the request parameters are invalid' do
      context 'because there are unknown parameters' do
        it 'returns an 400 Bad Request' do
          get :index, guid: app_model.guid, invalid: 'thing', bad: 'stuff'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Unknown query parameter(s): 'invalid', 'bad'")
        end
      end

      context 'because there are invalid values in parameters' do
        it 'returns an 400 Bad Request' do
          get :index, guid: app_model.guid, per_page: 50000

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include('Per page must be between')
        end
      end
    end
  end

  describe '#terminate' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:app_process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: space) }
    let(:index_stopper) { instance_double(VCAP::CloudController::IndexStopper) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::IndexStopper).to receive(:new).and_return(index_stopper)
      allow(index_stopper).to receive(:stop_index)
    end

    it 'terminates the lone process' do
      expect(app_process.instances).to eq(1)

      delete :terminate, guid: app_model.guid, type: app_process.type, index: 0

      expect(response.status).to eq(204)
      expect(index_stopper).to have_received(:stop_index).with(app_process, 0)
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        delete :terminate, guid: app_model.guid, type: app_process.type, index: 0

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    it 'returns a 404 if app does not exist' do
      delete :terminate, guid: 'sad-bad-guid', type: app_process.type, index: 0

      expect(response.status).to eq(404)
      expect(response.body).to include 'ResourceNotFound'
      expect(response.body).to include 'App not found'
    end

    it 'returns a 404 if process type does not exist' do
      delete :terminate, guid: app_model.guid, type: 'bad-type', index: 0

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Process not found')
    end

    it 'returns a 404 if instance index out of bounds' do
      delete :terminate, guid: app_model.guid, type: app_process.type, index: 1

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Instance not found')
    end

    context 'when the user cannot read the app' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'raises 404' do
        delete :terminate, guid: app_model.guid, type: app_process.type, index: 0

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user cannot terminate the process due to membership' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
      end

      it 'rVCAP::CloudController::aises an ApiError with a 403 code' do
        delete :terminate, guid: app_model.guid, type: app_process.type, index: 0

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'terminates the lone process' do
        expect(app_process.instances).to eq(1)

        delete :terminate, guid: app_model.guid, type: app_process.type, index: 0

        expect(response.status).to eq(204)
        expect(index_stopper).to have_received(:stop_index).with(app_process, 0)
      end
    end
  end

  describe '#scale' do
    let(:body_params) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:app_process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: space) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
    end

    it 'scales the process and returns the correct things' do
      expect(app_process.instances).not_to eq(2)
      expect(app_process.memory).not_to eq(100)
      expect(app_process.disk_quota).not_to eq(200)

      put :scale, guid: app_model.guid, type: app_process.type, body: body_params

      app_process.reload
      expect(app_process.instances).to eq(2)
      expect(app_process.memory).to eq(100)
      expect(app_process.disk_quota).to eq(200)

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['guid']).to eq(app_process.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'scales the process and returns the correct things' do
        expect(app_process.instances).not_to eq(2)
        expect(app_process.memory).not_to eq(100)
        expect(app_process.disk_quota).not_to eq(200)

        put :scale, guid: app_model.guid, type: app_process.type, body: body_params

        app_process.reload
        expect(app_process.instances).to eq(2)
        expect(app_process.memory).to eq(100)
        expect(app_process.disk_quota).to eq(200)

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['guid']).to eq(app_process.guid)
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessScale).to receive(:scale).and_raise(VCAP::CloudController::ProcessScale::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        put :scale, guid: app_model.guid, type: app_process.type, body: body_params

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when scaling is disabled' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

      context 'user is non-admin' do
        it 'raises 403' do
          put :scale, guid: app_model.guid, type: app_process.type, body: body_params

          expect(response.status).to eq 403
          expect(response.body).to include 'FeatureDisabled'
          expect(response.body).to include 'app_scaling'
        end
      end

      context 'user is admin' do
        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'scales the process and returns the correct things' do
          expect(app_process.instances).not_to eq(2)
          expect(app_process.memory).not_to eq(100)
          expect(app_process.disk_quota).not_to eq(200)

          put :scale, guid: app_model.guid, type: app_process.type, body: body_params

          app_process.reload
          expect(app_process.instances).to eq(2)
          expect(app_process.memory).to eq(100)
          expect(app_process.disk_quota).to eq(200)

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['guid']).to eq(app_process.guid)
        end
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'raises an ApiError with a 403 code' do
        put :scale, guid: app_model.guid, type: app_process.type, body: body_params

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the request provides invalid data' do
      it 'returns 422' do
        put :scale, guid: app_model.guid, type: app_process.type, body: { instances: 'oops' }

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Instances is not a number'
      end
    end

    context 'when the app does not exist' do
      it 'raises 404' do
        put :scale, guid: 'foo', type: app_process.type

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include('App not found')
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        put :scale, guid: app_model.guid, type: 'bananas'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Process not found'
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

      it 'raises 404' do
        put :scale, guid: app_model.guid, type: app_process.type

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user cannot scale the process due to membership' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
      end

      it 'raises an ApiError with a 403 code' do
        put :scale, guid: app_model.guid, type: app_process.type

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end

  describe '#show' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:app_process) { VCAP::CloudController::App.make(app_guid: app_model.guid, space_guid: space.guid) }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
    end

    it 'returns 200 OK and the process' do
      get :show, guid: app_model.guid, type: app_process.type

      expect(response.status).to eq 200
      expect(MultiJson.load(response.body)['guid']).to eq(app_process.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200 OK and the process' do
        get :show, guid: app_model.guid, type: app_process.type

        expect(response.status).to eq 200
        expect(MultiJson.load(response.body)['guid']).to eq(app_process.guid)
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, guid: 'not-real', type: app_process.type

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end

    context 'when the user does not have read permissions' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'raises an ApiError with a 403 code' do
        get :show, guid: app_model.guid, type: app_process.type

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, guid: app_model.guid, type: 'boo'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Process not found'
      end
    end

    context 'when the user cannot read the process due to roles' do
      before do
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'raises 404' do
        get :show, guid: app_model.guid, type: app_process.type

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'App not found'
      end
    end
  end
end
