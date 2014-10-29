require 'spec_helper'

module VCAP::CloudController
  describe ProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:process_repo) { instance_double(ProcessRepository) }
    let(:app_model) { AppFactory.make }
    let(:process) { AppProcess.new(app_model) }
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

      context 'when the process does exist' do
        before do
          allow(process_repo).to receive(:find_by_guid).and_return(process)
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 200' do
          response_code, _ = process_controller.show(guid)
          expect(response_code).to eq 200
        end

        it 'returns the process in JSON format' do
          expected_response = {
            'guid' => process.guid,
          }

          _ , json_body = process_controller.show(app_model.guid)
          response_hash = MultiJson.load(json_body)

          expect(response_hash).to match(expected_response)
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
          'stack_guid' => Stack.make.guid
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
      let(:req_body) do
        {
          'name' => 'my-process',
          'memory' => 256,
          'instances' => 2,
          'disk_quota' => 1024,
          'space_guid' => Space.make.guid,
          'stack_guid' => Stack.make.guid
        }.to_json
      end

      context 'when the user cannot update an process' do
        before do
          allow(process_repo).to receive(:find_by_guid).and_return(process)
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

      context 'when the process does not exist' do
        before do
          allow(process_repo).to receive(:find_by_guid).and_return(nil)
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

      context 'when a user can update a process' do
        before do
          expect(process_repo).to receive(:find_by_guid).and_return(process)
          expect(process_repo).to receive(:update).and_return(process)
          expect(process_repo).to receive(:persist!).and_return(process)
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 200 Ok response' do
          response_code, _ = process_controller.update(guid)
          expect(response_code).to eq 200
        end

        it 'returns the process information in JSON format' do
          expected_response = {
            'guid' => process.guid,
          }

          _, json_body = process_controller.update(process.guid)
          response_hash = MultiJson.load(json_body)

          expect(response_hash).to match(expected_response)
        end
      end
    end


    # These tests are not strictly necessary, the unit tests above
    # cover the same code.
    describe 'GET /v3/processes/:guid' do
      it '404s when the process does not exist' do
        user = User.make
        get '/v3/processes/non-existing', {}, headers_for(user)
        expect(last_response.status).to eq(404)
      end

      context 'permissions' do
        it 'returns a 404 for an unauthorized user' do
          user = User.make
          process = AppFactory.make
          get "/v3/processes/#{process.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'POST /v3/processes' do
      it 'returns a 422 when the params are invalid' do
        invalid_opts = {
          'space_guid' => Space.make.guid,
        }
        post '/v3/processes', invalid_opts.to_json, admin_headers
        expect(last_response.status).to eq(422)
      end

      context 'permissions' do
        it 'returns a 404 for an unauthorized user' do
          user = User.make
          valid_opts = {
            'name' => 'my-process',
            'memory' => 256,
            'instances' => 2,
            'disk_quota' => 1024,
            'space_guid' => Space.make.guid,
            'stack_guid' => Stack.make.guid
          }
          post '/v3/processes', valid_opts.to_json, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'DELETE /v3/processes/:guid' do
      it 'returns a 404 when the process does not exist' do
        delete '/v3/processes/bogus-guid', {}, admin_headers
        expect(last_response.status).to eq(404)
      end

      context 'permissions' do
        it 'returns a 404 for an unauthorized user' do
          user = User.make
          process = AppFactory.make
          delete "/v3/processes/#{process.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'PATCH /v3/processes/:guid' do
      it 'returns a 404 when the process does not exist' do
        patch '/v3/processes/bogus-guid', {}.to_json, admin_headers
        expect(last_response.status).to eq(404)
      end

      context 'permissions' do
        let(:user) { User.make }
        let(:process) { AppFactory.make }

        it 'returns a 404 when the user is unauthorized to update the initial process' do
          patch "/v3/processes/#{process.guid}", {}.to_json, headers_for(user)
          expect(last_response.status).to eq(404)
        end

        it 'returns a 404 when the user is unauthorized to update to the desired state' do
          process.space.organization.add_user(user)
          process.space.add_developer(user)
          space2 = Space.make

          patch "/v3/processes/#{process.guid}", { 'space_guid' => space2.guid }.to_json, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
