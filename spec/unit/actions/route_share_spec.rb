require 'spec_helper'
require 'actions/route_share'

module VCAP::CloudController
  RSpec.describe RouteShare do
    let(:route_share) { RouteShare.new }
    let(:route) { Route.make }
    let(:target_space1) { Space.make }
    let(:target_space2) { Space.make }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }

    describe '#create' do
      before do
        allow_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_share)
      end

      it 'creates share' do
        shared_route = route_share.create(route, [target_space1, target_space2], user_audit_info)
        # The target_space variable will not refresh its routes anymore after we added a call to grab the shared routes with the space to the
        # Validation of shared routes. If we just reload the target_space1 object we can get the new version of target_space1 & 2's shared routes.
        target_space1.reload
        target_space2.reload
        expect(shared_route.shared_spaces.length).to eq 2

        expect(target_space1.routes_shared_from_other_spaces.length).to eq 1
        expect(target_space2.routes_shared_from_other_spaces.length).to eq 1

        expect(target_space1.routes_shared_from_other_spaces[0]).to eq route
        expect(target_space2.routes_shared_from_other_spaces[0]).to eq route
      end

      it 'records a share event' do
        expect_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_share).with(
          route, user_audit_info, [target_space1.guid, target_space2.guid])

        route_share.create(route, [target_space1, target_space2], user_audit_info)
      end

      context 'when sharing one space from the list of spaces fails' do
        before do
          allow(route).to receive(:add_shared_space).with(target_space1).and_call_original
          allow(route).to receive(:add_shared_space).with(target_space2).and_raise('db failure')
        end

        it 'does not share with any spaces' do
          expect {
            route_share.create(route, [target_space1, target_space2], user_audit_info)
          }.to raise_error('db failure')

          route.reload
          expect(route.shared_spaces.length).to eq 0
        end
      end

      context 'when source space is included in list of target spaces' do
        it 'does not share with any spaces' do
          expect {
            route_share.create(route, [target_space1, route.space], user_audit_info)
          }.to raise_error(VCAP::CloudController::RouteShare::Error,
                           "Unable to share route '#{route.uri}' with space '#{route.space.guid}'. Routes cannot be shared into the space where they were created.")

          route.reload

          expect(route.shared_spaces.length).to eq 0
        end
      end
    end
  end
end
