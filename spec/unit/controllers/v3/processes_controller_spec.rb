require 'spec_helper'
require 'handlers/processes_handler'

module VCAP::CloudController
  describe ProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:processes_handler) { instance_double(ProcessesHandler) }
    let(:process_presenter) { double(:process_presenter) }
    let(:process_model) { AppFactory.make(app_guid: app_model.guid) }
    let(:app_model) { AppModel.make }
    let(:process) { ProcessMapper.map_model_to_domain(process_model) }
    let(:guid) { process.guid }
    let(:membership) { double(:membership) }
    let(:req_body) { '' }
    let(:expected_response) { 'process_response_body' }

    let(:processes_controller) do
      ProcessesController.new(
        {},
        logger,
        {},
        {},
        req_body,
        nil,
        {
          processes_handler: processes_handler,
          process_presenter: process_presenter
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(process_presenter).to receive(:present_json).and_return(expected_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(processes_controller).to receive(:current_user).and_return(User.make)
      allow(processes_controller).to receive(:membership).and_return(membership)
      allow(processes_controller).to receive(:check_write_permissions!).and_return(nil)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:list_response) { 'list_response' }

      before do
        allow(process_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(processes_handler).to receive(:list).and_return(list_response)
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = processes_controller.list

        expect(processes_handler).to have_received(:list)
        expect(process_presenter).to have_received(:present_json_list).with(list_response, '/v3/processes')
        expect(response_code).to eq(200)
        expect(response_body).to eq(expected_response)
      end
    end

    describe '#show' do
      before do
        allow(processes_handler).to receive(:show).and_return(process)
      end

      context 'when the process does not exist' do
        let(:guid) { 'ABC123' }
        before do
          allow(processes_handler).to receive(:show).and_return(nil)
        end

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

      it 'returns 200 OK' do
        response_code, _ = processes_controller.show(guid)
        expect(response_code).to eq(HTTP::OK)
      end

      it 'returns the process information' do
        _, response = processes_controller.show(guid)
        expect(response).to eq(expected_response)
      end
    end

    describe '#update' do
      let(:new_space) { Space.make }
      let(:req_body) do
        {
          'memory' => 256,
          'instances' => 2,
          'disk_quota' => 1024,
          'space_guid' => new_space.guid,
          'stack_guid' => Stack.make.guid,
        }.to_json
      end

      before do
        allow(processes_handler).to receive(:update).and_return(process)
      end

      it 'returns a 200 OK response' do
        response_code, _ = processes_controller.update(guid)
        expect(response_code).to eq(HTTP::OK)
      end

      it 'returns the process information' do
        _, response = processes_controller.update(guid)
        expect(response).to eq(expected_response)
      end

      context 'when the user cannot update to the desired state' do
        let(:desired_process) { AppProcess.new({ space_guid: new_space.guid }) }

        before do
          allow(processes_handler).to receive(:update).and_raise(ProcessesHandler::Unauthorized)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the process does not exist' do
        before do
          allow(processes_handler).to receive(:update).and_return(nil)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when persisting the process fails because it is invalid due to an error' do
        let(:req_body) do
          {
            name: 'a-new-name'
          }.to_json
        end

        before do
          allow(processes_handler).to receive(:update).and_raise(ProcessesHandler::InvalidProcess)
        end

        it 'raises an UnprocessableEntity with a 422' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end

      context 'when persisting the process fails because it is invalid due to validation' do
        let(:req_body) do
          {
            name: 'a-new-name'
          }.to_json
        end

        it 'raises an UnprocessableEntity with a 422' do
          expect {
            processes_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
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
