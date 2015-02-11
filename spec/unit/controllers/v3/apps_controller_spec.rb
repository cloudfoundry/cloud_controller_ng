require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:package_handler) { double(:package_handler) }
    let(:package_presenter) { double(:package_presenter) }
    let(:apps_handler) { double(:apps_handler) }
    let(:app_model) { nil }
    let(:app_presenter) { double(:app_presenter) }
    let(:apps_controller) do
      AppsV3Controller.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          apps_handler:      apps_handler,
          app_presenter:     app_presenter,
          packages_handler:  package_handler,
          package_presenter: package_presenter
        },
      )
    end
    let(:app_response) { 'app_response_body' }

    before do
      allow(logger).to receive(:debug)
      allow(apps_handler).to receive(:show).and_return(app_model)
      allow(app_presenter).to receive(:present_json).and_return(app_response)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:list_response) { 'list_response' }

      before do
        allow(app_presenter).to receive(:present_json_list).and_return(app_response)
        allow(apps_handler).to receive(:list).and_return(list_response)
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = apps_controller.list

        expect(apps_handler).to have_received(:list)
        expect(app_presenter).to have_received(:present_json_list).with(list_response, {})
        expect(response_code).to eq(200)
        expect(response_body).to eq(app_response)
      end

      context 'query params' do
        context('invalid param format') do
          let(:names) { 'foo' }
          let(:params) { { 'names' => names } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Invalid type')
            end
          end
        end

        context 'unknow query param' do
          let(:bad_param) { 'foo' }
          let(:params) { { 'bad_param' => bad_param } }

          it 'returns 400' do
            expect {
              apps_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Unknow query param')
            end
          end
        end
      end
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

        it 'returns a 200' do
          response_code, _ = apps_controller.show(guid)
          expect(response_code).to eq 200
        end

        it 'returns the app' do
          _, response = apps_controller.show(guid)
          expect(response).to eq(app_response)
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

      before do
        allow(apps_handler).to receive(:create).and_return(app_model)
      end

      context 'when the user cannot create an app' do
        before do
          allow(apps_handler).to receive(:create).and_raise(AppsHandler::Unauthorized)
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

      context 'when the app is invalid' do
        before do
          allow(apps_handler).to receive(:create).and_raise(AppsHandler::InvalidApp.new('ya done goofed'))
        end

        it 'returns an UnprocessableEntity error' do
          expect {
            apps_controller.create
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('ya done goofed')
          end
        end
      end

      context 'when a user can create a app' do
        it 'returns a 201 Created response' do
          response_code, _ = apps_controller.create
          expect(response_code).to eq 201
        end

        it 'returns the app' do
          _, response = apps_controller.create
          expect(response).to eq(app_response)
        end
      end
    end

    describe '#update' do
      let!(:app_model) { AppModel.make }
      let(:new_name) { 'new-name' }
      let(:req_body) do
        {
          name: new_name,
        }.to_json
      end

      before do
        allow(apps_handler).to receive(:update).and_return(app_model)
      end

      context 'when the user cannot update the app' do
        before do
          allow(apps_handler).to receive(:update).and_raise(AppsHandler::Unauthorized)
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
        let(:app_response) do
          {
            'guid' => app_model.guid,
            'name' => new_name,
          }
        end

        it 'returns a 200 OK response' do
          response_code, _ = apps_controller.update(app_model.guid)
          expect(response_code).to eq 200
        end

        it 'returns the app information' do
          _, response = apps_controller.update(app_model.guid)
          expect(response).to eq(app_response)
        end
      end

      context 'when the app does not exist' do
        let(:guid) { 'bad-guid' }

        before do
          allow(apps_handler).to receive(:update).and_return(nil)
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

      context 'when the app is invalid' do
        before do
          allow(apps_handler).to receive(:update).and_raise(AppsHandler::InvalidApp.new('ya done goofed'))
        end

        it 'returns an UnprocessableEntity error' do
          expect {
            apps_controller.update(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('ya done goofed')
          end
        end
      end

      context 'when the droplet was not found' do
        before do
          allow(apps_handler).to receive(:update).and_raise(AppsHandler::DropletNotFound)
        end

        it 'returns an NotFound error' do
          expect {
            apps_controller.update(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
          end
        end
      end
    end

    describe '#delete' do
      before do
        allow(apps_handler).to receive(:delete).and_return(true)
      end

      context 'when the user cannot update the app' do
        before do
          allow(apps_handler).to receive(:delete).and_raise(AppsHandler::Unauthorized)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.delete('guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does not exist' do
        before do
          allow(apps_handler).to receive(:delete).and_return(nil)
        end

        it 'raises an ApiError with a 404 code' do
          expect {
            apps_controller.delete('guid')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the app does exist' do
        it 'returns a 204' do
          response_code, _ = apps_controller.delete('guid')
          expect(response_code).to eq 204
        end

        context 'when the app has child processes' do
          before do
            allow(apps_handler). to receive(:delete).and_raise(AppsHandler::DeleteWithProcesses)
          end

          it 'raises a 400' do
            expect {
              _, _ = apps_controller.delete('guid')
            }.to raise_error do |error|
              expect(error.name).to eq 'UnableToPerform'
              expect(error.response_code).to eq 400
            end
          end
        end
      end
    end
  end
end
