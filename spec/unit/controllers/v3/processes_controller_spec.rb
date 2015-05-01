require 'spec_helper'

module VCAP::CloudController
  describe ProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:process_presenter) { double(:process_presenter) }
    let(:user) { User.make }
    let(:space) { Space.make }
    let(:app_model) { AppModel.make(space: space) }
    let(:process) { AppFactory.make(app_guid: app_model.guid) }
    let(:guid) { process.guid }
    let(:membership) { double(:membership) }
    let(:req_body) { '' }
    let(:expected_response) { 'process_response_body' }
    let(:params) { {} }

    let(:processes_controller) do
      ProcessesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          process_presenter: process_presenter
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(process_presenter).to receive(:present_json).and_return(expected_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(membership).to receive(:admin?).and_return(false)
      allow(processes_controller).to receive(:current_user).and_return(user)
      allow(processes_controller).to receive(:membership).and_return(membership)
      allow(processes_controller).to receive(:check_write_permissions!).and_return(nil)
      allow(processes_controller).to receive(:check_read_permissions!).and_return(nil)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:list_response) { 'list_response' }

      before do
        allow(process_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(membership).to receive(:space_guids_for_roles).and_return([space.guid])
        allow_any_instance_of(ProcessListFetcher).to receive(:fetch).and_call_original
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = processes_controller.list

        expect(process_presenter).to have_received(:present_json_list).with(instance_of(PaginatedResult), '/v3/processes')
        expect(response_code).to eq(200)
        expect(response_body).to eq(expected_response)
      end

      it 'fetches processes for the users SpaceDeveloper, SpaceManager, SpaceAuditor, OrgManager space guids' do
        expect_any_instance_of(ProcessListFetcher).to receive(:fetch).with(instance_of(PaginationOptions), [space.guid]).and_call_original
        expect_any_instance_of(ProcessListFetcher).to_not receive(:fetch_all)

        processes_controller.list

        expect(membership).to have_received(:space_guids_for_roles).with(
            [Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
      end

      it 'checks for read permissions' do
        processes_controller.list

        expect(processes_controller).to have_received(:check_read_permissions!)
      end

      context 'when user is an admin' do
        before do
          allow(membership).to receive(:admin?).and_return(true)
        end

        it 'fetches all of the results' do
          expect_any_instance_of(ProcessListFetcher).to receive(:fetch_all).with(instance_of(PaginationOptions)).and_call_original

          processes_controller.list
        end
      end

      context 'when the request parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              processes_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include("Unknown query param(s) 'invalid', 'bad'")
            end
          end
        end

        context 'because there are invalid values in parameters' do
          let(:params) { { 'per_page' => 'foo' } }

          it 'returns an 400 Bad Request' do
            expect {
              processes_controller.list
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
      it 'returns 200 OK' do
        response_code, _ = processes_controller.show(guid)
        expect(response_code).to eq(HTTP::OK)
      end

      it 'returns the process information' do
        _, response = processes_controller.show(guid)
        expect(response).to eq(expected_response)
      end

      context 'when the user does not have read permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(processes_controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            processes_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the process does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            processes_controller.show(guid)
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
            processes_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to eq 'Process not found'
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process.space.guid, process.space.organization.guid)
        end
      end
    end

    describe '#update' do
      let(:req_body) do
        {
          'command' => 'new command',
        }.to_json
      end

      it 'updates the process and returns the correct things' do
        expect(process.command).not_to eq('new command')

        status, body = processes_controller.update(process.guid)

        expect(process.reload.command).to eq('new command')
        expect(status).to eq(HTTP::OK)
        expect(body).to eq(expected_response)
      end

      context 'when the process does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            processes_controller.update('made-up-guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request body is invalid JSON' do
        let(:req_body) { '{ invalid_json }' }

        it 'returns an 400 Bad Request' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the user does not have write permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(processes_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            processes_controller.update(guid)
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
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('errorz')
          end
        end
      end

      context 'when the request provides invalid data' do
        let(:req_body) { '{"command": false}' }

        it 'returns 422' do
          expect {
            processes_controller.update(guid)
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
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process.space.guid, process.space.organization.guid)
        end
      end

      context 'when the user cannot update the process due to membership' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true, false)
        end

        it 'raises an ApiError with a 403 code' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], process.space.guid)
        end
      end
    end

    describe '#scale' do
      let(:req_body) { '{"instances": 2}' }
      let(:process) { AppFactory.make }

      it 'scales the process and returns the correct things' do
        expect(process.instances).not_to eq(2)

        status, body = processes_controller.scale(process.guid)

        expect(process.reload.instances).to eq(2)
        expect(status).to eq(HTTP::OK)
        expect(body).to eq(expected_response)
      end

      context 'when the process is invalid' do
        before do
          allow_any_instance_of(ProcessScale).to receive(:scale).and_raise(ProcessScale::InvalidProcess.new('errorz'))
        end

        it 'returns 422' do
          expect {
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('errorz')
          end
        end
      end

      context 'when scaling is disabled' do
        before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

        it 'raises 403' do
          expect {
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'FeatureDisabled'
            expect(error.response_code).to eq 403
            expect(error.message).to match('app_scaling')
          end
        end
      end

      context 'when the user does not have write permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(processes_controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the request body is invalid JSON' do
        let(:req_body) { '{ invalid_json }' }
        it 'returns an 400 Bad Request' do
          expect {
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the request provides invalid data' do
        let(:req_body) { '{"instances": "wrong"}' }

        it 'returns 422' do
          expect {
            processes_controller.scale(process.guid)
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
            processes_controller.scale('made-up-guid')
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
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end

          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], process.space.guid, process.space.organization.guid)
        end
      end

      context 'when the user cannot scale the process due to membership' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true, false)
        end

        it 'raises an ApiError with a 403 code' do
          expect {
            processes_controller.scale(process.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER], process.space.guid)
        end
      end
    end
  end
end
