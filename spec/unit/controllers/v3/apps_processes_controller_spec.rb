require 'spec_helper'

module VCAP::CloudController
  describe AppsProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:processes_handler) { double(:processes_handler) }
    let(:process_presenter) { double(:process_presenter) }
    let(:apps_handler) { double(:apps_handler) }
    let(:app_model) { nil }
    let(:controller) do
      AppsProcessesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          apps_handler:      apps_handler,
          processes_handler: processes_handler,
          process_presenter: process_presenter,
        },
      )
    end
    let(:process_response) { 'process_response_body' }

    before do
      allow(logger).to receive(:debug)
      allow(apps_handler).to receive(:show).and_return(app_model)
      allow(process_presenter).to receive(:present_json_list).and_return(process_response)
    end

    describe '#add_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make(type: 'special') }
      let(:process_guid) { process.guid }
      let(:req_body) do
        MultiJson.dump({ process_guid: process_guid })
      end

      before do
        allow(processes_handler).to receive(:show).and_return(process)
        allow(apps_handler).to receive(:show).and_return(app_model)
        allow(apps_handler).to receive(:add_process).and_return(true)
      end

      context 'when the app does not exist' do
        before do
          allow(apps_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot update the app' do
        before do
          allow(apps_handler).to receive(:add_process).and_raise(AppsHandler::Unauthorized)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.add_process(guid)
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
            controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process does not exist' do
        let(:process) { nil }
        let(:process_guid) { 'non-existant-guid' }

        it 'returns a 404 Not Found' do
          expect {
            controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app already has a process with the same type' do
        let(:req_body) do
          MultiJson.dump({ process_guid: process_guid })
        end
        before do
          allow(apps_handler).to receive(:add_process).and_raise(AppsHandler::DuplicateProcessType)
        end

        it 'returns a 400 Invalid' do
          expect {
            controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ProcessInvalid'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process is in a different space' do
        before do
          allow(apps_handler).to receive(:add_process).and_raise(AppsHandler::IncorrectProcessSpace)
        end

        it 'returns an UnableToPerform error' do
          expect {
            _, _ = controller.add_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnableToPerform'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process is added to the app' do
        it 'returns a 204 No Content response' do
          response_code, _ = controller.add_process(guid)
          expect(response_code).to eq(204)
        end
      end
    end

    describe '#remove_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make }
      let(:process_guid) { process.guid }
      let(:req_body) do
        MultiJson.dump({ process_guid: process_guid })
      end

      before do
        allow(apps_handler).to receive(:show).and_return(app_model)
        allow(processes_handler).to receive(:show).and_return(process)
      end

      context 'when the process is added to the app' do
        before do
          allow(apps_handler).to receive(:remove_process)
        end

        it 'returns a 204 No Content response' do
          response_code, _ = controller.remove_process(guid)
          expect(response_code).to eq(204)
        end
      end

      context 'when the user cannot update the app' do
        before do
          allow(apps_handler).to receive(:remove_process).and_raise(AppsHandler::Unauthorized)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.remove_process(guid)
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
            controller.remove_process(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process does not exist' do
        before do
          allow(processes_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 Not Found' do
          expect {
            controller.remove_process(guid)
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
            controller.list_processes(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }
        let(:list_response) { 'list_response' }

        before do
          allow(process_presenter).to receive(:present_json_list).and_return(process_response)
          allow(processes_handler).to receive(:list).and_return(list_response)
        end

        it 'returns a 200' do
          response_code, _ = controller.list_processes(guid)
          expect(response_code).to eq 200
        end

        it 'returns the processes' do
          _, response = controller.list_processes(guid)
          expect(response).to eq(process_response)
        end
      end
    end

    describe '#process_procfile' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:req_body) do
        'clock: bundle spec clock'
      end

      before do
        allow(apps_handler).to receive(:process_procfile)
        allow(processes_handler).to receive(:list)
      end

      context 'when the app does not exist' do
        before do
          allow(apps_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.process_procfile(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot update the app' do
        before do
          allow(apps_handler).to receive(:process_procfile).and_raise(AppsHandler::Unauthorized)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.process_procfile(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request body is invalid Procfile' do
        let(:req_body) { 'invalid procfile' }
        before do
          allow(Procfile).to receive(:load).and_raise(Procfile::ParseError)
        end

        it 'returns an 400 Bad Request' do
          expect {
            controller.process_procfile(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'MessageParseError'
            expect(error.response_code).to eq 400
          end
        end
      end

      context 'when the process is added to the app' do
        it 'returns a 200 OK' do
          response_code, _ = controller.process_procfile(guid)
          expect(response_code).to eq(200)
        end
      end
    end
  end
end
