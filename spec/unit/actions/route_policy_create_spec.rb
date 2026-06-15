require 'spec_helper'
require 'actions/route_policy_create'

module VCAP::CloudController
  RSpec.describe RoutePolicyCreate do
    subject(:action) { RoutePolicyCreate.new }

    let(:space) { Space.make }
    let(:domain) { SharedDomain.make(name: 'apps.identity', enforce_route_policies: true) }
    let(:route) { Route.make(space:, domain:) }
    let(:app_guid) { SecureRandom.uuid }
    let(:message) { instance_double(RoutePolicyCreateMessage, source: "cf:app:#{app_guid}") }

    describe '#create' do
      it 'creates a route policy with the given source' do
        expect {
          action.create(route:, message:)
        }.to change(RoutePolicy, :count).by(1)

        policy = RoutePolicy.last
        expect(policy.source).to eq("cf:app:#{app_guid}")
        expect(policy.route_id).to eq(route.id)
      end

      context 'when the same source already exists for the route' do
        before do
          RoutePolicy.create(source: "cf:app:#{app_guid}", route_id: route.id)
        end

        it 'raises an error' do
          expect {
            action.create(route:, message:)
          }.to raise_error(RoutePolicyCreate::Error, /already exists for this route/)
        end
      end

      context 'when source is cf:any and other policies exist for the route' do
        let(:message) { instance_double(RoutePolicyCreateMessage, source: 'cf:any') }

        before do
          RoutePolicy.create(source: "cf:app:#{app_guid}", route_id: route.id)
        end

        it 'raises an error' do
          expect {
            action.create(route:, message:)
          }.to raise_error(RoutePolicyCreate::Error, /cannot add 'cf:any'/i)
        end
      end

      context 'when a cf:any policy already exists for the route' do
        before do
          RoutePolicy.create(source: 'cf:any', route_id: route.id)
        end

        it 'raises an error when adding any other source' do
          other_message = instance_double(RoutePolicyCreateMessage, source: "cf:app:#{SecureRandom.uuid}")
          expect {
            action.create(route:, message: other_message)
          }.to raise_error(RoutePolicyCreate::Error, /already has a 'cf:any' policy/)
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
          allow(route_relation).to receive(:for_update).and_return(route_relation)
          allow(route_relation).to receive(:first).and_return(route)
          allow(Route).to receive(:where).with(id: route.id).and_return(route_relation)

          action.create(route:, message:)

          expect(route_relation).to have_received(:for_update)
        end
      end
    end
  end
end
