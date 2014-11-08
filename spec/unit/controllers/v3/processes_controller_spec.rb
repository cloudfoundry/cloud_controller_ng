require 'spec_helper'
require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  describe ProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:process_repo) { instance_double(ProcessRepository) }
    let(:process_model) { AppFactory.make(app_guid: app_model.guid) }
    let(:app_model) { AppModel.make }
    let(:process) { ProcessMapper.map_model_to_domain(process_model) }
    let(:user) { User.make }
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
          { :process_repository => process_repo },
        )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#show' do
      context 'when the process does not exist' do
        let(:guid) { 'ABC123' }
        before do
          allow(process_repo).to receive(:find_by_guid).and_return(nil)
        end
        it 'raises an ApiError with a 404 code' do
          expect {
            process_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot access the process' do
        before do
          SecurityContext.set(user)
          allow(process_repo).to receive(:find_by_guid).and_return(process)
        end

        it 'raises a 404' do
          expect {
            process_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
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

      context 'when the user cannot create an process' do
        before do
          allow(process_repo).to receive(:new_process).and_return(process)
          SecurityContext.set(user)
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

      context 'when an the process cannot be created' do
        before do
          allow(process_repo).to receive(:new_process).and_raise(ProcessRepository::InvalidProcess)
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
          allow(process_repo).to receive(:new_process).and_return(process)
          allow(process_repo).to receive(:persist!).and_return(process)
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 201 Created response' do
          expect(process_repo).to receive(:persist!)

          response_code, _ = process_controller.create
          expect(response_code).to eq 201
        end

        it 'returns the process information in JSON format' do
          expected_response = {
            'guid' => process.guid,
          }
          expect(process_repo).to receive(:persist!)

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

      context 'when the user cannot update the initial process' do
        before do
          allow(process_repo).to receive(:find_by_guid_for_update).and_yield(process)
          SecurityContext.set(user)
        end

        it 'returns a 404 NotFound error' do
          expect {
            process_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot update to the desired state' do
        let(:desired_process) { AppProcess.new({space_guid: new_space.guid}) }

        before do
          allow(process_repo).to receive(:find_by_guid_for_update).and_yield(process)
          allow(process_repo).to receive(:update).and_return(desired_process)
          process_model.space.organization.add_user(user)
          process_model.space.add_developer(user)
          SecurityContext.set(user, { 'scope' => ['cloud_controller.write', 'cloud_controller.read'] })
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
          allow(process_repo).to receive(:find_by_guid_for_update).and_yield(nil)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            process_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when persisting the process fails' do
        before do
          allow(process_repo).to receive(:find_by_guid_for_update).and_yield(process)
          allow(process_repo).to receive(:update).and_return(process)
          allow(process_repo).to receive(:persist!).and_raise(ProcessRepository::InvalidProcess)
          process_model.space.organization.add_user(user)
          process_model.space.add_developer(user)
          SecurityContext.set(user, { 'scope' => ['cloud_controller.write', 'cloud_controller.read'] })
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
      context 'when the process does not exist' do
        before do
          allow(process_repo).to receive(:find_by_guid_for_update).and_return(nil)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            process_controller.delete(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot delete the process' do
        before do
          allow(process_repo).to receive(:find_by_guid_for_update).and_yield(process)
          SecurityContext.set(user)
        end

        it 'raises a 404' do
          expect {
            process_controller.delete(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end
  end
end
