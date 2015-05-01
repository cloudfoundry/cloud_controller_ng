require 'spec_helper'

module VCAP::CloudController
  describe AppsProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:process_presenter) { double(:process_presenter) }
    let(:membership) { double(:membership) }
    let(:controller) do
      AppsProcessesController.new(
        {},
        logger,
        {},
        params,
        req_body,
        nil,
        {
          process_presenter: process_presenter,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(controller).to receive(:membership).and_return(membership)
      allow(controller).to receive(:current_user).and_return(User.make)
    end

    describe '#list_processes' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }
      let(:list_response) { 'list_response' }

      before do
        allow(process_presenter).to receive(:present_json_list).and_return(list_response)
        allow(controller).to receive(:check_read_permissions!)
      end

      it 'returns a 200 and presents the response' do
        app_model.add_process(App.make(space: space))
        app_model.add_process(App.make(space: space))
        App.make
        App.make

        response_code, response = controller.list_processes(guid)
        expect(response_code).to eq 200

        expect(response).to eq(list_response)
        expect(process_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), "/v3/apps/#{guid}/processes") do |result|
              expect(result.total).to eq(2)
            end
      end

      context 'when the user does not have read permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            controller.list_processes(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

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

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            controller.list_processes(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the request parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              controller.list_processes(guid)
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
              controller.list_processes(guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Per page must be between 1 and 5000')
            end
          end
        end
      end
    end

    describe '#scale' do
      let(:req_body) { '{"instances": 2}' }
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make(app_guid: app.guid, space: space) }
      let(:expected_response) { 'some response' }

      before do
        allow(controller).to receive(:check_write_permissions!)
        allow(process_presenter).to receive(:present_json).and_return(expected_response)
      end

      it 'scales the process and returns the correct things' do
        expect(process.instances).not_to eq(2)

        status, body = controller.scale(app.guid, process.type)

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
            controller.scale(app.guid, process.type)
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
            controller.scale(app.guid, process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'FeatureDisabled'
            expect(error.response_code).to eq 403
            expect(error.message).to match('app_scaling')
          end
        end
      end

      context 'when the user does not have write permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(controller).to receive(:check_write_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            controller.scale(app.guid, process.type)
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
            controller.scale(app.guid, process.type)
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
            controller.scale(app.guid, process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'UnprocessableEntity'
            expect(error.response_code).to eq(422)
            expect(error.message).to match('Instances is not a number')
          end
        end
      end

      context 'when the app does not exist' do
        it 'raises 404' do
          expect {
            controller.scale('made-up-guid', process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to include('App not found')
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises 404' do
          expect {
            controller.scale(app.guid, 'made-up-type')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to include('Process not found')
          end
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'raises 404' do
          expect {
            controller.scale(app.guid, process.type)
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
            controller.scale(app.guid, process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER], process.space.guid)
        end
      end
    end

    describe '#show' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }
      let(:process) { App.make(app_guid: app.guid, space_guid: space.guid) }
      let(:expected_response) { 'some response' }

      before do
        allow(controller).to receive(:check_read_permissions!)
        allow(process_presenter).to receive(:present_json).and_return(expected_response)
      end

      it 'returns 200 OK and the process' do
        code, response = controller.show(app.guid, process.type)

        expect(code).to eq(HTTP::OK)
        expect(response).to eq(expected_response)
        expect(process_presenter).to have_received(:present_json).with(process)
      end

      context 'when the user does not have read permissions' do
        it 'raises an ApiError with a 403 code' do
          expect(controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            controller.show(app.guid, process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the app does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            controller.show('not-real', process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.message).to eq 'App not found'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises an ApiError with a 404 code' do
          expect {
            controller.show(app.guid, 'not-real')
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
            controller.show(app.guid, process.type)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq(404)
            expect(error.message).to eq 'App not found'
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], process.space.guid, process.space.organization.guid)
        end
      end
    end
  end
end
