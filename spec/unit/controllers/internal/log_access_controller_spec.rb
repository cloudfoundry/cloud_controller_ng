require 'spec_helper'
require 'fetchers/log_access_fetcher'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe LogAccessController do
    let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let(:logger) { instance_double(Steno::Logger) }

    let(:log_access_controller) do
      LogAccessController.new(
        double(Config, get: nil),
        logger,
        {},
        {},
        {},
        nil,
        {
          statsd_client: double(Statsd)
        }
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(LogAccessFetcher).to receive(:new).and_call_original
    end

    describe '#lookup' do
      context 'when the user does not have the cloud_controller.read scope' do
        it 'returns 403' do
          expect(log_access_controller).to receive(:check_read_permissions!).
            and_raise(CloudController::Errors::ApiError.new_from_details('NotAuthorized'))
          expect do
            log_access_controller.lookup(app_model.guid)
          end.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'when the app does not exist' do
        before do
          set_current_user_as_admin
        end

        it 'returns 404' do
          response_code = log_access_controller.lookup('some-fake-guid')
          expect(response_code).to eq(404)
        end
      end

      context 'when the app is found' do
        before do
          set_current_user_as_admin
        end

        it 'returns 200 when the app is found' do
          response_code = log_access_controller.lookup(app_model.guid)
          expect(response_code).to eq(200)
        end
      end
    end
  end
end
