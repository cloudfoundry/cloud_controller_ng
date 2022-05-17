require 'spec_helper'
require 'actions/route_unshare'

module VCAP::CloudController
  RSpec.describe RouteUnshare do
    let(:route_share) { RouteShare.new }
    let(:route_unshare) { RouteUnshare.new }
    let(:route) { Route.make }
    let(:target_space1) { Space.make }
    let(:target_space2) { Space.make }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }

    describe '#delete' do
      let(:target_space3) { Space.make }
      before do
        allow_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_unshare)
        route_share.create(route, [target_space1, target_space2, target_space3], user_audit_info)
      end

      it 'deletes share' do
        expect(route.shared_spaces.length).to eq 3
        expect(target_space1.routes_shared_from_other_spaces.length).to eq 1
        expect(target_space2.routes_shared_from_other_spaces.length).to eq 1
        expect(target_space3.routes_shared_from_other_spaces.length).to eq 1

        expect(target_space1.routes_shared_from_other_spaces[0]).to eq route
        expect(target_space2.routes_shared_from_other_spaces[0]).to eq route
        expect(target_space3.routes_shared_from_other_spaces[0]).to eq route

        modified_route = route_unshare.delete(route, target_space2, user_audit_info)
        # The target_space variable will not refresh its routes anymore after we added a call to grab the shared routes with the space to the
        # Validation of shared routes. If we just reload the objects we can get the new version of thh spaces shared routes.
        target_space1.reload
        target_space2.reload
        target_space3.reload
        expect(modified_route.shared_spaces.length).to eq 2

        expect(target_space1.routes_shared_from_other_spaces.length).to eq 1
        expect(target_space2.routes_shared_from_other_spaces.length).to eq 0
        expect(target_space3.routes_shared_from_other_spaces.length).to eq 1

        expect(target_space1.routes_shared_from_other_spaces[0]).to eq route
        expect(target_space2.routes_shared_from_other_spaces[0]).to be_nil
        expect(target_space3.routes_shared_from_other_spaces[0]).to eq route
      end

      it 'records a share event' do
        expect_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_unshare).with(
          route, user_audit_info, target_space2.guid)

        route_unshare.delete(route, target_space2, user_audit_info)
      end

      context 'when unsharing a space fails' do
        before do
          allow(route).to receive(:remove_shared_space).with(target_space1).and_raise('db failure')
        end

        it 'does not unshare the space' do
          expect(route.shared_spaces.length).to eq 3

          expect {
            route_unshare.delete(route, target_space1, user_audit_info)
          }.to raise_error('db failure')

          route.reload
          expect(route.shared_spaces.length).to eq 3
        end
      end

      context 'when attempting to unshare the owning space' do
        it 'does not permit you to unshare that space' do
          expect {
            route_unshare.delete(route, route.space, user_audit_info)
          }.to raise_error(VCAP::CloudController::RouteUnshare::Error,
                           "Unable to unshare route '#{route.uri}' from space '#{route.space.guid}'. Routes cannot be removed from the space that owns them.")

          route.reload

          expect(route.shared_spaces.length).to eq 3
        end
      end
    end
  end
end
