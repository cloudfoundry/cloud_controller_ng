require 'spec_helper'
require 'handlers/processes_handler'

module VCAP::CloudController
  describe ProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:processes_handler) { instance_double(ProcessesHandler) }
    let(:process_model) { AppFactory.make(app_guid: app_model.guid) }
    let(:app_model) { AppModel.make }
    let(:process) { ProcessMapper.map_model_to_domain(process_model) }
    let(:guid) { process.guid }
    let(:req_body) {''}
    let(:process_controller) do
        ProcessesController.new(
          {},
          logger,
          {},
          {},
          req_body,
          nil,
          { :processes_handler => processes_handler },
        )
    end

    before do
      allow(logger).to receive(:debug)
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
            process_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'Process not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      it 'returns 200 OK' do
        response_code, _ = process_controller.show(guid)
        expect(response_code).to eq(HTTP::OK)
      end

      it 'returns the process information in JSON format' do
        expected_response = {
          'guid' => process.guid,
        }

        _, json_body = process_controller.show(guid)
        response_hash = MultiJson.load(json_body)

        expect(response_hash).to match(expected_response)
      end
    end

    describe '#create' do
      let(:req_body) do
        {
          'name' => 'my-process',
          'memory' => 256,
          'instances' => 2,
          'disk_quota' => 1024,
          'space_guid' => Space.make.guid,
          'stack_guid' => Stack.make.guid,
          'app_guid' => app_model.guid,
        }.to_json
      end

      context 'when the user cannot create a process because they are unauthorized' do
        before do
          allow(processes_handler).to receive(:create).and_raise(ProcessesHandler::Unauthorized)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            process_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the process cannot be created because it is invalid' do
        before do
          allow(processes_handler).to receive(:create).and_raise(ProcessesHandler::InvalidProcess)
        end

        it 'returns an UnprocessableEntity error' do
          expect {
            process_controller.create
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
            process_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when a user can create a process' do
        before do
          allow(processes_handler).to receive(:create).and_return(process)
        end

        it 'returns a 201 Created response' do
          response_code, _ = process_controller.create
          expect(response_code).to eq(HTTP::CREATED)
        end

        it 'returns the process information in JSON format' do
          expected_response = {
            'guid' => process.guid,
          }

          _, json_body = process_controller.create
          response_hash = MultiJson.load(json_body)

          expect(response_hash).to match(expected_response)
        end
      end
    end

    describe '#update' do
      let(:new_space) { Space.make }
      let(:req_body) do
        {
          'name' => 'my-process',
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
        response_code, _ = process_controller.update(guid)
        expect(response_code).to eq(HTTP::OK)
      end

      it 'returns the process information in JSON format' do
        expected_response = {
          'guid' => process.guid,
        }

        _, json_body = process_controller.update(guid)
        response_hash = MultiJson.load(json_body)

        expect(response_hash).to match(expected_response)
      end

      context 'when the user cannot update to the desired state' do
        let(:desired_process) { AppProcess.new({ space_guid: new_space.guid }) }

        before do
          allow(processes_handler).to receive(:update).and_raise(ProcessesHandler::Unauthorized)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            process_controller.update(guid)
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
            process_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when persisting the process fails because it is invalid' do
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
            process_controller.update(guid)
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
            process_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end
    end

    describe 'delete' do
      before do
        allow(processes_handler).to receive(:delete).and_return(true)
      end

      it 'returns a 204 No Content response' do
        response_code, _ = process_controller.delete(guid)
        expect(response_code).to eq(HTTP::NO_CONTENT)
      end

      context 'when the process does not exist' do
        before do
          allow(processes_handler).to receive(:delete).and_return(false)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            process_controller.delete(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end
  end
end
