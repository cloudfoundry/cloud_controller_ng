require 'spec_helper'
require 'queries/log_access_fetcher'

module VCAP::CloudController
  describe LogAccessController do
    let(:user) { User.make }
    let(:guid) { 'v2-or-v3-app-guid' }
    let(:space_guids) { ['guid-1', 'guid-2'] }
    let(:roles) { double(:roles) }
    let(:membership) { double(:membership) }
    let(:fetcher) { double(:fetcher, app_exists?: true, app_exists_by_space?: true) }
    let(:logger) { instance_double(Steno::Logger) }

    let(:log_access_controller) do
      LogAccessController.new(
        {},
        logger,
        {},
        {},
        {},
        nil,
        {},
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(log_access_controller).to receive(:check_read_permissions!)
      allow(LogAccessFetcher).to receive(:new).and_return(fetcher)
      allow(log_access_controller).to receive(:membership).and_return(membership)
      allow(log_access_controller).to receive(:current_user).and_return(user)
      allow(VCAP::CloudController::Roles).to receive(:new).and_return(roles)
    end

    describe '#lookup' do
      context 'when the user is unauthorized' do
        it 'returns 403' do
          expect(log_access_controller).to receive(:check_read_permissions!).
            and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
          expect {
            log_access_controller.lookup(guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end

      context 'permissions' do
        context 'admin user' do
          before do
            allow(roles).to receive(:admin?).and_return(true)
          end

          it 'uses admin permissions' do
            log_access_controller.lookup(guid)
            expect(fetcher).to have_received(:app_exists?).with(guid)
          end
        end

        context 'non admin  user' do
          before do
            allow(roles).to receive(:admin?).and_return(false)
            allow(membership).to receive(:space_guids_for_roles).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER],
            ).and_return(space_guids)
          end

          it 'checks for read permissions' do
            log_access_controller.lookup(guid)
            expect(log_access_controller).to have_received(:check_read_permissions!)
            expect(fetcher).to have_received(:app_exists_by_space?).with(guid, space_guids)
          end
        end
      end

      context 'when the app does not exist' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
          allow(fetcher).to receive(:app_exists?).with('some-guid').and_return(false)
        end

        it 'returns 404' do
          response_code = log_access_controller.lookup('some-guid')
          expect(response_code).to eq(404)
        end
      end

      context 'when the app is found' do
        before do
          allow(roles).to receive(:admin?).and_return(true)
        end

        it 'returns 200 when the app is found' do
          response_code = log_access_controller.lookup(guid)
          expect(response_code).to eq(200)
        end
      end
    end
  end
end
