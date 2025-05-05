require 'spec_helper'
require 'actions/route_transfer_owner'

module VCAP::CloudController
  RSpec.describe RouteTransferOwner do
    let(:route_share) { RouteShare.new }
    let(:route) { Route.make domain: SharedDomain.make, space: original_owning_space }
    let(:original_owning_space) { Space.make name: 'original_owning_space' }
    let(:target_space) { Space.make name: 'target_space' }
    let(:target_space_dup_name) { Space.make name: 'original_owning_space' }
    let(:shared_space) { Space.make name: 'shared_space' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }

    describe '#transfer' do
      before do
        route_share.create(route, [shared_space], user_audit_info)
      end

      it 'makes the target space the new owner' do
        RouteTransferOwner.transfer(route, target_space, user_audit_info)
        expect(route.space.id).to eq target_space.id
      end

      context 'route was previously shared with the target space' do
        before do
          route_share.create(route, [target_space], user_audit_info)
        end

        it 'removes the target space from the list of shared spaces' do
          expect(route.shared_spaces.map(&:id)).to include target_space.id
          RouteTransferOwner.transfer(route, target_space, user_audit_info)
          route.reload
          expect(route.shared_spaces.map(&:id)).not_to include target_space.id
        end
      end

      it 'shares the route with the original owning space' do
        expect(route.shared_spaces.map(&:id)).not_to include original_owning_space.id
        RouteTransferOwner.transfer(route, target_space, user_audit_info)
        route.reload
        expect(route.shared_spaces.map(&:id)).to include original_owning_space.id
      end

      context 'target space is already the owning space' do
        it 'does nothing and succeeds' do
          expect { RouteTransferOwner.transfer(route, original_owning_space, user_audit_info) }.not_to raise_error
          expect(route.shared_spaces.map(&:id)).not_to include original_owning_space.id
          expect(route.space.id).to eq original_owning_space.id
        end
      end

      context 'target space has the same name as the owning space' do
        it 'makes the target space with the same name the new owner' do
          RouteTransferOwner.transfer(route, target_space_dup_name, user_audit_info)
          expect(route.space.id).to eq target_space.id
        end
      end

      it 'records a transfer event', isolation: :truncation do
        expect_any_instance_of(Repositories::RouteEventRepository).to receive(:record_route_transfer_owner).with(
          route, user_audit_info, original_owning_space, target_space.guid
        )

        RouteTransferOwner.transfer(route, target_space, user_audit_info)
      end

      context 'when tranfering ownership fails' do
        before do
          allow(route).to receive(:save).and_raise('db failure')
        end

        it 'does not change the owning space' do
          expect_any_instance_of(Repositories::RouteEventRepository).not_to receive(:record_route_transfer_owner).with(
            route, user_audit_info, original_owning_space, target_space.guid
          )
          expect(route.space.id).to eq original_owning_space.id
          expect do
            RouteTransferOwner.transfer(route, target_space, user_audit_info)
          end.to raise_error('db failure')
          route.reload
          expect(route.space.id).to eq original_owning_space.id
        end

        it 'does not change the shared spaces' do
          expect_any_instance_of(Repositories::RouteEventRepository).not_to receive(:record_route_transfer_owner).with(
            route, user_audit_info, original_owning_space, target_space.guid
          )
          expect(route.shared_spaces.length).to eq 1
          expect(route.shared_spaces.map(&:id)).to include shared_space.id
          expect do
            RouteTransferOwner.transfer(route, target_space, user_audit_info)
          end.to raise_error('db failure')
          route.reload
          expect(route.shared_spaces.map(&:id)).to include shared_space.id
          expect(route.shared_spaces.length).to eq 1
        end
      end
    end
  end
end
