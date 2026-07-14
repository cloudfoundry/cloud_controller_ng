require 'spec_helper'
require 'actions/route_policy_update'

module VCAP::CloudController
  RSpec.describe RoutePolicyUpdate do
    subject(:action) { RoutePolicyUpdate.new(user_audit_info) }

    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: 'some-user-guid') }
    let(:space) { create(:space) }
    let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
    let(:route) { create(:route, space:, domain:) }
    let(:app_guid) { SecureRandom.uuid }
    let(:route_policy) { create(:route_policy, source: "cf:app:#{app_guid}", route: route) }
    let(:message) do
      RoutePolicyUpdateMessage.new(metadata: { labels: { 'key' => 'value' }, annotations: { 'a' => 'note' } })
    end

    describe '#update' do
      it 'applies the label metadata update' do
        action.update(route_policy, message)

        expect(route_policy.reload.labels.map { |l| [l.key_name, l.value] }).to include(%w[key value])
      end

      it 'applies the annotation metadata update' do
        action.update(route_policy, message)

        expect(route_policy.reload.annotations.map { |a| [a.key_name, a.value] }).to include(%w[a note])
      end

      it 'records a route_policy_update audit event with the requested metadata' do
        expect_any_instance_of(Repositories::RoutePolicyEventRepository).
          to receive(:record_route_policy_update).once.
          with(route_policy, user_audit_info, { 'metadata' => { 'labels' => { 'key' => 'value' }, 'annotations' => { 'a' => 'note' } } })

        action.update(route_policy, message)
      end

      it 'returns the route policy' do
        expect(action.update(route_policy, message)).to eq(route_policy)
      end

      context 'when recording the audit event fails inside the transaction' do
        before do
          allow_any_instance_of(Repositories::RoutePolicyEventRepository).
            to receive(:record_route_policy_update).and_raise('boom')
        end

        it 'rolls back the metadata update' do
          expect { action.update(route_policy, message) }.to raise_error('boom')

          expect(route_policy.reload.labels).to be_empty
          expect(route_policy.reload.annotations).to be_empty
        end
      end
    end
  end
end
