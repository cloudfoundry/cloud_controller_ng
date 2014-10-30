require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:req_body) {''}
    let(:apps_controller) do
      AppsV3Controller.new(
          {},
          logger,
          {},
          {},
          req_body,
          nil,
          {},
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
            expect(error.name).to eq 'NotFound'
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
              expect(error.name).to eq 'NotFound'
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
          space_guid: Space.make.guid,
        }.to_json
      end

      context 'when the user cannot create an process' do
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
  end
end
