require 'rails_helper'

module VCAP::CloudController
  describe ProcessesController, type: :controller do
    let(:process_presenter) { double(:process_presenter) }
    let(:space) { Space.make }
    let(:membership) { instance_double(Membership) }
    let(:roles) { instance_double(Roles) }
    let(:expected_response) { 'process_response_body' }

    before do
      allow(Roles).to receive(:new).and_return(roles)
      allow(roles).to receive(:admin?).and_return(false)
      allow_any_instance_of(ProcessesController).to receive(:process_presenter).and_return(process_presenter)
      allow_any_instance_of(ProcessesController).to receive(:membership).and_return(membership)
    end

    describe '#index' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:list_response) { 'list_response' }

      before do
        @request.env.merge!(headers_for(User.make))
        allow(process_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(membership).to receive(:space_guids_for_roles).and_return([space.guid])
        allow_any_instance_of(ProcessListFetcher).to receive(:fetch).and_call_original
      end

      it 'returns 200 and lists the apps' do
        get :index

        expect(process_presenter).to have_received(:present_json_list).with(instance_of(PaginatedResult), '/v3/processes')
        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns 200 and lists the apps' do
          expect_any_instance_of(ProcessListFetcher).to receive(:fetch_all).with(instance_of(PaginationOptions)).and_call_original

          get :index

          expect(process_presenter).to have_received(:present_json_list).with(instance_of(PaginatedResult), '/v3/processes')
          expect(response.status).to eq(200)
          expect(response.body).to eq(expected_response)
        end
      end

      it 'fetches processes for the users SpaceDeveloper, SpaceManager, SpaceAuditor, OrgManager space guids' do
        expect_any_instance_of(ProcessListFetcher).to receive(:fetch).with(instance_of(PaginationOptions), [space.guid]).and_call_original
        expect_any_instance_of(ProcessListFetcher).to_not receive(:fetch_all)

        get :index

        expect(membership).to have_received(:space_guids_for_roles).with(
                                  [Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
      end

      it 'fails without read permissions scope on the auth token' do
        @request.env['HTTP_AUTHORIZATION'] = ''
        expect {
          get :index
        }.to raise_error do |error|
          expect(error.name).to eq('NotAuthorized')
        end
      end

      context 'when the request parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              get :index, params
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include("Unknown query parameter(s): 'invalid', 'bad'")
            end
          end
        end

        context 'because there are invalid values in parameters' do
          let(:params) { { 'per_page' => 10000 } }

          it 'returns an 400 Bad Request' do
            expect {
              get :index, params
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Per page must be between 1 and 5000')
            end
          end
        end
      end
    end

    describe '#show' do
      let(:process_type) { App.make }

      before do
        @request.env.merge!(headers_for(User.make))
        allow(process_presenter).to receive(:present_json).and_return(expected_response)
        allow(membership).to receive(:has_any_roles?).and_return(true)
      end

      it 'returns 200 OK with process' do
        get :show, { guid: process_type.guid }

        expect(response.status).to eq(HTTP::OK)
        expect(response.body).to eq(expected_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns 200 OK with process' do
          get :show, { guid: process_type.guid }

          expect(response.status).to eq(HTTP::OK)
          expect(response.body).to eq(expected_response)
        end
      end

      context 'when the user does not have read permissions' do
        before { @request.env['HTTP_AUTHORIZATION'] = '' }
        it 'raises an ApiError with a 403 code' do
          expect {
            get :show, { guid: process_type.guid }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            get :show, { guid: 'ABC123' }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'Process not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the process due to roles' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'raises 404' do
          expect {
            get :show, { guid: process_type.guid }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to eq 'Process not found'
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
        end
      end
    end

    describe '#update' do
      let(:process_type) { App.make }
      let(:req_body) do
        {
            'command' => 'new command',
        }
      end

      before do
        @request.env.merge!(headers_for(User.make))
        allow(process_presenter).to receive(:present_json).and_return(expected_response)
        allow(membership).to receive(:has_any_roles?).and_return(true)
      end

      it 'updates the process and returns the correct things' do
        expect(process_type.command).not_to eq('new command')

        patch :update, { guid: process_type.guid, body: req_body }

        expect(process_type.reload.command).to eq('new command')
        expect(response.status).to eq(HTTP::OK)
        expect(response.body).to eq(expected_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'updates the process and returns the correct things' do
          expect(process_type.command).not_to eq('new command')

          patch :update, { guid: process_type.guid, body: req_body }

          expect(process_type.reload.command).to eq('new command')
          expect(response.status).to eq(HTTP::OK)
          expect(response.body).to eq(expected_response)
        end
      end

      context 'when the process does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            patch :update, { guid: 'made-up-guid', body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user does not have write permissions' do
        before { @request.env['HTTP_AUTHORIZATION'] = '' }

        it 'raises an ApiError with a 403 code' do
          expect {
            patch :update, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the process is invalid' do
        before do
          allow_any_instance_of(ProcessUpdate).to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('errorz'))
        end

        it 'returns 422' do
          expect {
            patch :update, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('errorz')
          end
        end
      end

      context 'when the request provides invalid data' do
        let(:req_body) { { command: false } }

        it 'returns 422' do
          expect {
            patch :update, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to include('Command must be a string')
          end
        end
      end

      context 'when the user cannot read the process' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'raises 404' do
          expect {
            patch :update, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
        end
      end

      context 'when the user cannot update the process due to membership' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true, false)
        end

        it 'raises an ApiError with a 403 code' do
          expect {
            patch :update, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], process_type.space.guid)
        end
      end
    end

    describe '#terminate' do
      let(:process_type) { AppFactory.make }
      let(:index_stopper) { double(:index_stopper) }

      before do
        @request.env.merge!(headers_for(User.make))
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
          allow(roles).to receive(:admin?).and_return(true)
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
        expect {
          put :terminate, { guid: 'bad-guid', index: 0 }
        }.to raise_error do |error|
          expect(error.name).to eq 'ResourceNotFound'
          expect(error.response_code).to eq(404)
          expect(error.message).to match('Process not found')
        end
      end

      it 'returns a 404 if instance index out of bounds' do
        expect {
          put :terminate, { guid: process_type.guid, index: 1 }
        }.to raise_error do |error|
          expect(error.name).to eq 'ResourceNotFound'
          expect(error.response_code).to eq(404)
          expect(error.message).to match('Instance not found')
        end
      end

      context 'when the user does not have write permissions' do
        before { @request.env['HTTP_AUTHORIZATION'] = '' }

        it 'raises an ApiError with a 403 code' do
          expect {
            put :terminate, { guid: process_type.guid, index: 0 }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the user cannot read the process' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'raises 404' do
          expect {
            put :terminate, { guid: process_type.guid, index: 0 }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
        end
      end

      context 'when the user cannot update the process due to membership' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true, false)
        end

        it 'raises an ApiError with a 403 code' do
          expect {
            put :terminate, { guid: process_type.guid, index: 0 }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], process_type.space.guid)
        end
      end
    end

    describe '#scale' do
      let(:req_body) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
      let(:process_type) { AppFactory.make }

      before do
        @request.env.merge!(headers_for(User.make))
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
        expect(response.status).to eq(HTTP::OK)
        expect(response.body).to eq(expected_response)
      end

      context 'admin' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
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
          expect(response.status).to eq(HTTP::OK)
          expect(response.body).to eq(expected_response)
        end
      end

      context 'when the process is invalid' do
        before do
          allow_any_instance_of(ProcessScale).to receive(:scale).and_raise(ProcessScale::InvalidProcess.new('errorz'))
        end

        it 'returns 422' do
          expect {
            put :scale, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('errorz')
          end
        end
      end

      context 'when scaling is disabled' do
        before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

        context 'non-admin user' do
          it 'raises 403' do
            expect {
              put :scale, { guid: process_type.guid, body: req_body }
            }.to raise_error do |error|
              expect(error.name).to eq 'FeatureDisabled'
              expect(error.response_code).to eq 403
              expect(error.message).to match('app_scaling')
            end
          end
        end

        context 'admin user' do
          before { allow(roles).to receive(:admin?).and_return(true) }

          it 'scales the process and returns the correct things' do
            expect(process_type.instances).not_to eq(2)
            expect(process_type.memory).not_to eq(100)
            expect(process_type.disk_quota).not_to eq(200)

            put :scale, { guid: process_type.guid, body: req_body }

            process_type.reload
            expect(process_type.instances).to eq(2)
            expect(process_type.memory).to eq(100)
            expect(process_type.disk_quota).to eq(200)
            expect(response.status).to eq(HTTP::OK)
            expect(response.body).to eq(expected_response)
          end
        end
      end

      context 'when the user does not have write permissions' do
        before { @request.env['HTTP_AUTHORIZATION'] = '' }

        it 'raises an ApiError with a 403 code' do
          expect {
            put :scale, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the request provides invalid data' do
        let(:req_body) { { instances: 'wrong' } }

        it 'returns 422' do
          expect {
            put :scale, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('Instances is not a number')
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises 404' do
          expect {
            put :scale, { guid: 'fake-guid', body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end
        end
      end

      context 'when the user cannot read the process' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'raises 404' do
          expect {
            put :scale, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end

          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], process_type.space.guid, process_type.space.organization.guid)
        end
      end

      context 'when the user cannot scale the process due to membership' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true, false)
        end

        it 'raises an ApiError with a 403 code' do
          expect {
            put :scale, { guid: process_type.guid, body: req_body }
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER], process_type.space.guid)
        end
      end
    end
  end
end
