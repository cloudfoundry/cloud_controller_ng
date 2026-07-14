require 'spec_helper'
require 'actions/route_policy_destroy'

module VCAP::CloudController
  RSpec.describe RoutePolicyDestroy do
    subject(:action) { RoutePolicyDestroy.new(user_audit_info) }

    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: 'some-user-guid') }
    let(:space) { create(:space) }
    let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
    let(:route) { create(:route, space:, domain:) }
    let(:app_guid) { SecureRandom.uuid }
    let!(:route_policy) { create(:route_policy, source: "cf:app:#{app_guid}", route: route) }

    describe '#delete' do
      it 'destroys the route policy' do
        expect { action.delete(route_policy) }.to change(RoutePolicy, :count).by(-1)
      end

      it 'notifies diego after destroying' do
        expect(route_policy).to receive(:notify_diego).once

        action.delete(route_policy)
      end

      it 'records a route_policy_delete audit event' do
        expect_any_instance_of(Repositories::RoutePolicyEventRepository).
          to receive(:record_route_policy_delete).once.
          with(route_policy, user_audit_info)

        action.delete(route_policy)
      end

      context 'when recording the audit event fails inside the transaction' do
        before do
          allow_any_instance_of(Repositories::RoutePolicyEventRepository).
            to receive(:record_route_policy_delete).and_raise('boom')
        end

        it 'rolls back the destroy and does not notify diego' do
          expect(route_policy).not_to receive(:notify_diego)

          expect do
            expect { action.delete(route_policy) }.to raise_error('boom')
          end.not_to change(RoutePolicy, :count)
        end
      end
    end
  end
end
