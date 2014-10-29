require 'spec_helper'

module VCAP::CloudController
  describe AppsV3Controller do
    let(:logger) { instance_double(Steno::Logger) }
    let(:app_model) { AppModel.make }
    let(:user) { User.make }
    let(:guid) { app_model.guid }
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

      context 'when the user cannot access the process' do
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

      context 'when the app does exist' do
        before do
          SecurityContext.set(user, { 'scope' => [Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        end

        it 'returns a 200' do
          response_code, _ = apps_controller.show(guid)
          expect(response_code).to eq 200
        end

        it 'returns the app in JSON format' do
          _ , json_body = apps_controller.show(app_model.guid)
          expect { MultiJson.load(json_body) }.to_not raise_error
        end
      end
    end
  end
end
