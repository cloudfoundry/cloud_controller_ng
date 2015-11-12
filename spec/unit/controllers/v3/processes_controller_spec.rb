require 'rails_helper'

describe ProcessesController, type: :controller do
  let(:process_presenter) { double(:process_presenter) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:membership) { instance_double(VCAP::CloudController::Membership) }
  let(:expected_response) { 'process_response_body' }

  before do
    allow_any_instance_of(ProcessesController).to receive(:process_presenter).and_return(process_presenter)
    allow_any_instance_of(ProcessesController).to receive(:membership).and_return(membership)
  end

  describe '#index' do
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:list_response) { 'list_response' }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(process_presenter).to receive(:present_json_list).and_return(expected_response)
      allow(membership).to receive(:space_guids_for_roles).and_return([space.guid])
      allow_any_instance_of(VCAP::CloudController::ProcessListFetcher).to receive(:fetch).and_call_original
    end

    it 'returns 200 and lists the apps' do
      get :index

      expect(process_presenter).to have_received(:present_json_list).with(instance_of(VCAP::CloudController::PaginatedResult), '/v3/processes')
      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200 and lists the apps' do
        expect_any_instance_of(VCAP::CloudController::ProcessListFetcher).to receive(:fetch_all).with(instance_of(VCAP::CloudController::PaginationOptions)).and_call_original

        get :index

        expect(process_presenter).to have_received(:present_json_list).with(instance_of(VCAP::CloudController::PaginatedResult), '/v3/processes')
        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
      end
    end

    it 'fetches processes for the users SpaceDeveloper, SpaceManager, SpaceAuditor, OrgManager space guids' do
      expect_any_instance_of(VCAP::CloudController::ProcessListFetcher).to receive(:fetch).with(
        instance_of(VCAP::CloudController::PaginationOptions), [space.guid]).and_call_original
      expect_any_instance_of(VCAP::CloudController::ProcessListFetcher).to_not receive(:fetch_all)

      get :index

      expect(membership).to have_received(:space_guids_for_roles).with(
                                [VCAP::CloudController::Membership::SPACE_DEVELOPER,
                                 VCAP::CloudController::Membership::SPACE_MANAGER,
                                 VCAP::CloudController::Membership::SPACE_AUDITOR,
                                 VCAP::CloudController::Membership::ORG_MANAGER])
    end

    it 'fails without read permissions scope on the auth token' do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      get :index

      expect(response.status).to eq(403)
      expect(response.body).to include('NotAuthorized')
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
    let(:process_type) { VCAP::CloudController::App.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(process_presenter).to receive(:present_json).and_return(expected_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns 200 OK with process' do
      get :show, { guid: process_type.guid }

      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200 OK with process' do
        get :show, { guid: process_type.guid }

        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
      end
    end

    context 'when the user does not have read permissions' do
      before { @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])) }
      it 'raises an ApiError with a 403 code' do
        get :show, { guid: process_type.guid }

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, { guid: 'ABC123' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')
      end
    end

    context 'when the user cannot read the process due to roles' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'raises 404' do
        get :show, { guid: process_type.guid }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
        expect(response.body).to include('Process not found')

        expect(membership).to have_received(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
      end
    end
  end

  describe '#update' do
    let(:process_type) { VCAP::CloudController::App.make }
    let(:req_body) do
      {
          'command' => 'new command',
      }
    end

    before do
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow(process_presenter).to receive(:present_json).and_return(expected_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'updates the process and returns the correct things' do
      expect(process_type.command).not_to eq('new command')

      patch :update, { guid: process_type.guid, body: req_body }

      expect(process_type.reload.command).to eq('new command')
      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'updates the process and returns the correct things' do
        expect(process_type.command).not_to eq('new command')

        patch :update, { guid: process_type.guid, body: req_body }

        expect(process_type.reload.command).to eq('new command')
        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
      end
    end

    context 'when the process does not exist' do
      it 'raises an ApiError with a 404 code' do
        patch :update, { guid: 'made-up-guid', body: req_body }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have write permissions' do
      before { @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))) }

      it 'raises an ApiError with a 403 code' do
        patch :update, { guid: process_type.guid, body: req_body }

        expect(response.body).to include('NotAuthorized')
        expect(response.status).to eq(403)
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessUpdate).to receive(:update).and_raise(VCAP::CloudController::ProcessUpdate::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        patch :update, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when the request provides invalid data' do
      let(:req_body) { { command: false } }

      it 'returns 422' do
        patch :update, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Command must be a string')
      end
    end

    context 'when the user cannot read the process' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'raises 404' do
        patch :update, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')

        expect(membership).to have_received(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
      end
    end

    context 'when the user cannot update the process due to membership' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(true, false)
      end

      it 'raises an ApiError with a 403 code' do
        patch :update, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq 403
        expect(response.body).to include('NotAuthorized')

        expect(membership).to have_received(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], process_type.space.guid)
      end
    end
  end

  describe '#terminate' do
    let(:process_type) { VCAP::CloudController::AppFactory.make }
    let(:index_stopper) { double(:index_stopper) }

    before do
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow(index_stopper).to receive(:stop_index)
      allow_any_instance_of(ProcessesController).to receive(:index_stopper).and_return(index_stopper)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'terminates the lone process' do
      expect(process_type.instances).to eq(1)

      put :terminate, { guid: process_type.guid, index: 0 }
      expect(response.status).to eq(204)

      process_type.reload
      expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'terminates the lone process' do
        expect(process_type.instances).to eq(1)

        put :terminate, { guid: process_type.guid, index: 0 }
        expect(response.status).to eq(204)

        process_type.reload
        expect(index_stopper).to have_received(:stop_index).with(process_type, 0)
      end
    end

    it 'returns a 404 if process does not exist' do
      put :terminate, { guid: 'bad-guid', index: 0 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Process not found')
    end

    it 'returns a 404 if instance index out of bounds' do
      put :terminate, { guid: process_type.guid, index: 1 }

      expect(response.status).to eq(404)
      expect(response.body).to include('ResourceNotFound')
      expect(response.body).to include('Instance not found')
    end

    context 'when the user does not have write permissions' do
      before { @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))) }

      it 'raises an ApiError with a 403 code' do
        put :terminate, { guid: process_type.guid, index: 0 }

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user cannot read the process' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'raises 404' do
        put :terminate, { guid: process_type.guid, index: 0 }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')

        expect(membership).to have_received(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
      end
    end

    context 'when the user cannot update the process due to membership' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(true, false)
      end

      it 'raises an ApiError with a 403 code' do
        put :terminate, { guid: process_type.guid, index: 0 }

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')

        expect(membership).to have_received(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], process_type.space.guid)
      end
    end
  end

  describe '#scale' do
    let(:req_body) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
    let(:process_type) { VCAP::CloudController::AppFactory.make }

    before do
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow(process_presenter).to receive(:present_json).and_return(expected_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'scales the process and returns the correct things' do
      expect(process_type.instances).not_to eq(2)
      expect(process_type.memory).not_to eq(100)
      expect(process_type.disk_quota).not_to eq(200)

      put :scale, { guid: process_type.guid, body: req_body }

      process_type.reload
      expect(process_type.instances).to eq(2)
      expect(process_type.memory).to eq(100)
      expect(process_type.disk_quota).to eq(200)
      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'scales the process and returns the correct things' do
        expect(process_type.instances).not_to eq(2)
        expect(process_type.memory).not_to eq(100)
        expect(process_type.disk_quota).not_to eq(200)

        put :scale, { guid: process_type.guid, body: req_body }

        process_type.reload
        expect(process_type.instances).to eq(2)
        expect(process_type.memory).to eq(100)
        expect(process_type.disk_quota).to eq(200)
        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
      end
    end

    context 'when the process is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ProcessScale).to receive(:scale).and_raise(VCAP::CloudController::ProcessScale::InvalidProcess.new('errorz'))
      end

      it 'returns 422' do
        put :scale, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('errorz')
      end
    end

    context 'when scaling is disabled' do
      before { VCAP::CloudController::FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

      context 'non-admin user' do
        it 'raises 403' do
          put :scale, { guid: process_type.guid, body: req_body }

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('app_scaling')
        end
      end

      context 'admin user' do
        before { @request.env.merge!(json_headers(admin_headers)) }

        it 'scales the process and returns the correct things' do
          expect(process_type.instances).not_to eq(2)
          expect(process_type.memory).not_to eq(100)
          expect(process_type.disk_quota).not_to eq(200)

          put :scale, { guid: process_type.guid, body: req_body }

          process_type.reload
          expect(process_type.instances).to eq(2)
          expect(process_type.memory).to eq(100)
          expect(process_type.disk_quota).to eq(200)
          expect(response.status).to eq(200)
          expect(response.body).to eq(expected_response)
        end
      end
    end

    context 'when the user does not have write permissions' do
      before { @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))) }

      it 'raises an ApiError with a 403 code' do
        put :scale, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq 403
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the request provides invalid data' do
      let(:req_body) { { instances: 'wrong' } }

      it 'returns 422' do
        put :scale, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Instances is not a number')
      end
    end

    context 'when the process does not exist' do
      it 'raises 404' do
        put :scale, { guid: 'fake-guid', body: req_body }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user cannot read the process' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'raises 404' do
        put :scale, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')

        expect(membership).to have_received(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
      end
    end

    context 'when the user cannot scale the process due to membership' do
      before do
        allow(membership).to receive(:has_any_roles?).and_return(true, false)
      end

      it 'raises an ApiError with a 403 code' do
        put :scale, { guid: process_type.guid, body: req_body }

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')

        expect(membership).to have_received(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], process_type.space.guid)
      end
    end
  end
end
