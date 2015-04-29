require 'spec_helper'

module VCAP::CloudController
  describe AppsProcessesController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) { '' }
    let(:params) { {} }
    let(:process_presenter) { double(:process_presenter) }
    let(:app_model) { nil }
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
    let(:process_response) { 'process_response_body' }

    before do
      allow(logger).to receive(:debug)
      allow(process_presenter).to receive(:present_json_list).and_return(process_response)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(controller).to receive(:membership).and_return(membership)
      allow(controller).to receive(:check_read_permissions!).and_return(nil)
    end

    describe '#list_processes' do
      let(:app_model) { AppModel.make }
      let(:space) { app_model.space }
      let(:org) { space.organization }
      let(:guid) { app_model.guid }
      let(:list_response) { 'list_response' }

      it 'returns a 200 and presents the response' do
        app_model.add_process(App.make(space: space))
        app_model.add_process(App.make(space: space))
        App.make
        App.make

        response_code, response = controller.list_processes(guid)
        expect(response_code).to eq 200

        expect(response).to eq(process_response)
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
  end
end
