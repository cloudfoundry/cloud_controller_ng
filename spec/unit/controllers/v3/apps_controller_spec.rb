require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) {''}
    let(:app_repository) { AppRepository.new }
    let(:apps_controller) do
      AppsV3Controller.new(
          {},
          logger,
          {},
          {},
          req_body,
          nil,
          {
            process_repository: ProcessRepository.new,
            app_repository: app_repository,
          },
        )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#show' do
      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.show(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }

        context 'when the user cannot access the app' do
          before do
            SecurityContext.set(user)
          end

          it 'raises a 404' do
            expect {
              apps_controller.show(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the user has access to the app' do
          before do
            SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
          end

          it 'returns a 200' do
            response_code, _ = apps_controller.show(guid)
            expect(response_code).to eq 200
          end
        end
      end
    end

    describe '#create' do
      let(:req_body) do
        {
          name: 'some-name',
          space_guid: Space.make.guid,
        }.to_json
      end

      context 'when the user cannot create an app' do
        before do
          SecurityContext.set(user)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            apps_controller.create
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
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when a user can create a app' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 201 Created response' do
           response_code, _ = apps_controller.create
          expect(response_code).to eq 201
        end
      end
    end

    describe '#update' do
      let(:app_model) { AppModel.make }
      let(:new_name) { 'new-name' }
      let(:req_body) do
        {
          name: new_name,
        }.to_json
      end

      context 'when the user cannot update the app' do
        before do
          SecurityContext.set(user)
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            apps_controller.update(app_model.guid)
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
            apps_controller.update(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the user can update the app' do
        let(:req_body) { { name: new_name }.to_json }
        let(:expected_response) do
          {
            'guid' => app_model.guid,
            'name' => new_name,
          }
        end

        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 200 OK response' do
          response_code, _ = apps_controller.update(app_model.guid)
          expect(response_code).to eq 200
        end

        it 'returns the process information in JSON format' do
          _, json_body = apps_controller.update(app_model.guid)
          response_hash = MultiJson.load(json_body)

          expect(response_hash).to include(expected_response)
        end
      end

      context 'when the App does not exist' do
        let(:guid) { 'bad-guid' }

        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.update(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when persisting the app fails because it is invalid' do
        let(:app_repository) { double(:app_repository) }
        before do
          allow(app_repository).to receive(:find_by_guid_for_update).and_raise(AppRepository::InvalidApp)
        end

        it 'raises an UnprocessableEntity with a 422' do
          expect {
            apps_controller.update('some-guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq 422
          end
        end
      end
    end

    describe '#delete' do
      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.delete(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }

        context 'when the user cannot access the app' do
          before do
            SecurityContext.set(user)
          end

          it 'raises a 404' do
            expect {
              apps_controller.delete(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end

        context 'when the user has access to the app' do
          before do
            SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
          end

          it 'returns a 204' do
            response_code, _ = apps_controller.delete(guid)
            expect(response_code).to eq 204
          end
        end

        context 'when the app has child processes' do
          before do
            SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
            AppFactory.make(app_guid: guid)
          end

          it 'raises a 400' do
            expect {
             _, _ = apps_controller.delete(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'UnableToPerform'
              expect(error.response_code).to eq 400
            end
          end
        end
      end
    end

    describe '#add_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make(type: 'special') }
      let(:process_guid) { process.guid }
      let(:req_body) do
        MultiJson.dump({process_guid: process_guid})
      end

      context 'when the user cannot update the app' do
        before do
          SecurityContext.set(user)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            apps_controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request body is invalid JSON' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        let(:req_body) { '{ invalid_json }' }

        it 'returns an 400 Bad Request' do
          expect {
            apps_controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process does not exist' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        let(:process_guid) { 'non-existant-guid' }

        it 'returns a 404 Not Found' do
          expect {
            apps_controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app already has a process with the same type' do
        let(:req_body) do
          MultiJson.dump({process_guid: process_guid, type: 'special'})
        end
        before do
          app_model.add_process_by_guid(AppFactory.make(type: 'special').guid)
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 400 Invalid' do
          expect {
            apps_controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ProcessInvalid'
            expect(error.response_code).to eq 400
          end
        end
      end
      context 'when a user can add a process to the app' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 200 OK response' do
          response_code, _ = apps_controller.add_process(guid)
          expect(response_code).to eq 200
        end
      end
    end

    describe '#remove_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make }
      let(:process_guid) { process.guid }
      let(:req_body) do
        MultiJson.dump({process_guid: process_guid})
      end

      context 'when the user cannot update the app' do
        before do
          SecurityContext.set(user)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            apps_controller.remove_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request body is invalid JSON' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        let(:req_body) { '{ invalid_json }' }

        it 'returns an 400 Bad Request' do
          expect {
            apps_controller.remove_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process does not exist' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        let(:process_guid) { 'non-existant-guid' }

        it 'returns a 404 Not Found' do
          expect {
            apps_controller.remove_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#list_processes' do
      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.list_processes(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }

        context 'when the user cannot access the app' do
          before do
            SecurityContext.set(user)
          end

          it 'raises a 404' do
            expect {
              apps_controller.list_processes(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end
      end
    end
  end
end
