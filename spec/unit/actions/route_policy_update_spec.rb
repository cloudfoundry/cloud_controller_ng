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
    let(:route_policy) { RoutePolicy.create(source: "cf:app:#{app_guid}", route: route) }
    let(:message) do
      RoutePolicyUpdateMessage.new(metadata: { labels: { 'key' => 'value' }, annotations: { 'a' => 'note' } })
    end

    describe '#update' do
      it 'applies the metadata update' do
        action.update(route_policy, message)

        expect(route_policy.reload.labels.map { |l| [l.key_name, l.value] }).to include(%w[key value])
        expect(route_policy.annotations.map { |a| [a.key_name, a.value] }).to include(%w[a note])
      end

      it 'records a route_policy_update audit event' do
        expect_any_instance_of(Repositories::RoutePolicyEventRepository).
          to receive(:record_route_policy_update).
          with(route_policy, user_audit_info, message.audit_hash)

        action.update(route_policy, message)
      end

      it 'returns the route policy' do
        expect(action.update(route_policy, message)).to eq(route_policy)
      end
    end
  end
end
