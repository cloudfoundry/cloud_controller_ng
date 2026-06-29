require 'spec_helper'
require 'repositories/route_policy_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe RoutePolicyEventRepository do
      let(:user)             { create(:user) }
      let(:space)            { create(:space) }
      let(:domain)           { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
      let(:route)            { create(:route, space:, domain:) }
      let(:route_policy)     { RoutePolicy.create(source: 'cf:any', route: route) }
      let(:user_email)       { 'user@example.com' }
      let(:user_name)        { 'some-user' }
      let(:actor_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_name: user_name, user_email: user_email) }
      let(:request_attrs)    { { 'source' => 'cf:any', 'route_guid' => route.guid } }

      subject(:repo) { RoutePolicyEventRepository.new }

      shared_examples 'a route policy audit event' do |expected_type|
        it 'records the space, actee, actor and type' do
          expect(event.space).to eq(route_policy.route.space)
          expect(event.type).to eq(expected_type)
          expect(event.actee).to eq(route_policy.guid)
          expect(event.actee_type).to eq('route_policy')
          expect(event.actee_name).to eq(route_policy.source)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
        end
      end

      describe '#record_route_policy_create' do
        subject(:event) { repo.record_route_policy_create(route_policy, actor_audit_info, request_attrs).reload }

        include_examples 'a route policy audit event', 'audit.route_policy.create'

        it 'includes request attrs in metadata' do
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_route_policy_update' do
        subject(:event) { repo.record_route_policy_update(route_policy, actor_audit_info, request_attrs).reload }

        include_examples 'a route policy audit event', 'audit.route_policy.update'

        it 'includes request attrs in metadata' do
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_route_policy_delete' do
        subject(:event) { repo.record_route_policy_delete(route_policy, actor_audit_info).reload }

        include_examples 'a route policy audit event', 'audit.route_policy.delete'

        it 'has empty metadata' do
          expect(event.metadata).to eq({})
        end
      end
    end
  end
end
