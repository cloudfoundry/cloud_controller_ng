require 'spec_helper'
require 'actions/route_policy_create'

module VCAP::CloudController
  RSpec.describe RoutePolicyCreate do
    subject(:action) { RoutePolicyCreate.new }

    let(:space) { create(:space) }
    let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
    let(:route) { create(:route, space:, domain:) }
    let(:app_guid) { SecureRandom.uuid }
    let(:message) { instance_double(RoutePolicyCreateMessage, source: "cf:app:#{app_guid}") }

    describe '#create' do
      it 'creates a route policy with source_type and source_guid persisted' do
        expect do
          action.create(route:, message:)
        end.to change(RoutePolicy, :count).by(1)

        policy = RoutePolicy.last
        expect(policy.source).to eq("cf:app:#{app_guid}")
        expect(policy.source_type).to eq('app')
        expect(policy.source_guid).to eq(app_guid)
        expect(policy.route_id).to eq(route.id)
      end

      it 'persists source_type=any and source_guid="" for cf:any' do
        any_message = instance_double(RoutePolicyCreateMessage, source: 'cf:any')
        action.create(route: route, message: any_message)

        policy = RoutePolicy.last
        expect(policy.source_type).to eq('any')
        expect(policy.source_guid).to eq('')
      end

      context 'when the same source already exists for the route' do
        before do
          RoutePolicy.create(source: "cf:app:#{app_guid}", route_id: route.id)
        end

        it 'raises an error' do
          expect do
            action.create(route:, message:)
          end.to raise_error(RoutePolicyCreate::Error, /already exists for this route/)
        end
      end

      context 'when source is cf:any and other policies exist for the route' do
        let(:message) { instance_double(RoutePolicyCreateMessage, source: 'cf:any') }

        before do
          RoutePolicy.create(source: "cf:app:#{app_guid}", route_id: route.id)
        end

        it 'raises an error' do
          expect do
            action.create(route:, message:)
          end.to raise_error(RoutePolicyCreate::Error, /cannot add 'cf:any'/i)
        end
      end

      context 'when a cf:any policy already exists for the route' do
        before do
          RoutePolicy.create(source: 'cf:any', route_id: route.id)
        end

        it 'raises an error when adding any other source' do
          other_message = instance_double(RoutePolicyCreateMessage, source: "cf:app:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: other_message)
          end.to raise_error(RoutePolicyCreate::Error, /already has a 'cf:any' policy/)
        end
      end

      context 'when the domain has route_policies_scope: "space"' do
        let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true, route_policies_scope: 'space') }

        it 'allows cf:app sources' do
          expect do
            action.create(route:, message:)
          end.not_to raise_error
        end

        it 'allows cf:space sources' do
          space_message = instance_double(RoutePolicyCreateMessage, source: "cf:space:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: space_message)
          end.not_to raise_error
        end

        it 'rejects cf:org sources' do
          org_message = instance_double(RoutePolicyCreateMessage, source: "cf:org:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: org_message)
          end.to raise_error(RoutePolicyCreate::Error, /route_policies_scope.*space/i)
        end

        it 'allows cf:any sources' do
          any_message = instance_double(RoutePolicyCreateMessage, source: 'cf:any')
          expect do
            action.create(route: route, message: any_message)
          end.not_to raise_error
        end
      end

      context 'when the domain has route_policies_scope: "org"' do
        let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true, route_policies_scope: 'org') }

        it 'allows cf:app sources' do
          expect do
            action.create(route:, message:)
          end.not_to raise_error
        end

        it 'allows cf:space sources' do
          space_message = instance_double(RoutePolicyCreateMessage, source: "cf:space:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: space_message)
          end.not_to raise_error
        end

        it 'allows cf:org sources' do
          org_message = instance_double(RoutePolicyCreateMessage, source: "cf:org:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: org_message)
          end.not_to raise_error
        end

        it 'allows cf:any sources' do
          any_message = instance_double(RoutePolicyCreateMessage, source: 'cf:any')
          expect do
            action.create(route: route, message: any_message)
          end.not_to raise_error
        end
      end

      context 'when the domain has route_policies_scope: "any"' do
        let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true, route_policies_scope: 'any') }

        it 'allows cf:any sources' do
          any_message = instance_double(RoutePolicyCreateMessage, source: 'cf:any')
          expect do
            action.create(route: route, message: any_message)
          end.not_to raise_error
        end

        it 'allows cf:org sources' do
          org_message = instance_double(RoutePolicyCreateMessage, source: "cf:org:#{SecureRandom.uuid}")
          expect do
            action.create(route: route, message: org_message)
          end.not_to raise_error
        end
      end

      context 'when concurrent creates target the same route with no existing policies' do
        let(:message) { instance_double(RoutePolicyCreateMessage, source: 'cf:any') }

        it 'locks the parent route row to serialize creates and prevent cf:any exclusivity bypass' do
          # SELECT ... FOR UPDATE on an empty route_policies table acquires no row locks.
          # Two concurrent transactions can both read [], both pass cf:any exclusivity
          # validation, and both commit — leaving the route with cf:any + cf:app:<guid>.
          # The fix: lock the parent Route row (which always exists) before reading
          # policies, so concurrent transactions serialize at the route level.
          route_relation = spy('route relation')
          allow(route_relation).to receive_messages(for_update: route_relation, first: route)
          allow(Route).to receive(:where).with(id: route.id).and_return(route_relation)

          action.create(route:, message:)

          expect(route_relation).to have_received(:for_update)
        end
      end

      context 'when the route is deleted between controller fetch and transaction lock' do
        it 'raises an error' do
          route_relation = spy('route relation')
          allow(route_relation).to receive_messages(for_update: route_relation, first: nil)
          allow(Route).to receive(:where).with(id: route.id).and_return(route_relation)

          expect do
            action.create(route:, message:)
          end.to raise_error(RoutePolicyCreate::Error, /not found/)
        end
      end
    end
  end
end
