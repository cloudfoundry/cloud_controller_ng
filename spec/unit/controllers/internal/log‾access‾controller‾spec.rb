require 'spec_helper'
require 'fetchers/log_access_fetcher'

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
          statsd_client: double(Statsd),
          perm_client: double(Perm::Client)
        },
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
          expect {
            log_access_controller.lookup(app_model.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'permissions' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 200,
            'global_auditor' => 404,
            'space_developer' => 200,
            'space_manager' => 200,
            'space_auditor' => 200,
            'org_manager' => 200,
            'org_auditor' => 404,
            'org_billing_manager' => 404,
          }
        end

        roles = [
          'admin',
          'admin_read_only',
          'global_auditor',
          'space_developer',
          'space_manager',
          'space_auditor',
          'org_manager',
          'org_auditor',
          'org_billing_manager',
        ]

        roles.each do |role|
          describe "as an #{role}" do
            it 'returns the correct response status' do
              expected_return_value = roles_to_http_responses[role]
              set_current_user_as_role(role: role, org: org, space: space, user: user)
              response_code = log_access_controller.lookup(app_model.guid)

              expect(response_code).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response_code}"
            end
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
