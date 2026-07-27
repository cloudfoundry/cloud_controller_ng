require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RoutePolicy, type: :model do
    let(:space) { create(:space) }
    let(:domain) { create(:shared_domain, name: 'apps.identity') }
    let(:route) { create(:route, space:, domain:) }
    let(:app_model) { create(:app_model, space:) }
    let(:process) do
      create(:process_model, app: app_model, type: 'web')
    end
    let(:app_guid) { SecureRandom.uuid }

    before do
      create(:route_mapping_model, app: app_model, route: route, process_type: 'web')
    end

    describe 'source virtual attribute' do
      describe '#source getter' do
        it 'returns cf:app:<guid> composite string' do
          policy = RoutePolicy.new(source_type: 'app', source_guid: app_guid)
          expect(policy.source).to eq("cf:app:#{app_guid}")
        end

        it 'returns cf:space:<guid> composite string' do
          guid = SecureRandom.uuid
          policy = RoutePolicy.new(source_type: 'space', source_guid: guid)
          expect(policy.source).to eq("cf:space:#{guid}")
        end

        it 'returns cf:org:<guid> composite string' do
          guid = SecureRandom.uuid
          policy = RoutePolicy.new(source_type: 'org', source_guid: guid)
          expect(policy.source).to eq("cf:org:#{guid}")
        end

        it 'returns cf:any when source_guid is empty' do
          policy = RoutePolicy.new(source_type: 'any', source_guid: '')
          expect(policy.source).to eq('cf:any')
        end

        it 'returns cf:any when source_guid is nil' do
          policy = RoutePolicy.new(source_type: 'any', source_guid: nil)
          expect(policy.source).to eq('cf:any')
        end
      end

      describe '#source= setter' do
        it 'parses cf:app:<guid> into source_type and source_guid' do
          policy = RoutePolicy.new
          policy.source = "cf:app:#{app_guid}"
          expect(policy.source_type).to eq('app')
          expect(policy.source_guid).to eq(app_guid)
        end

        it 'parses cf:space:<guid>' do
          guid = SecureRandom.uuid
          policy = RoutePolicy.new
          policy.source = "cf:space:#{guid}"
          expect(policy.source_type).to eq('space')
          expect(policy.source_guid).to eq(guid)
        end

        it 'parses cf:org:<guid>' do
          guid = SecureRandom.uuid
          policy = RoutePolicy.new
          policy.source = "cf:org:#{guid}"
          expect(policy.source_type).to eq('org')
          expect(policy.source_guid).to eq(guid)
        end

        it 'sets source_type to any and source_guid to empty string for cf:any' do
          policy = RoutePolicy.new
          policy.source = 'cf:any'
          expect(policy.source_type).to eq('any')
          expect(policy.source_guid).to eq('')
        end

        it 'does nothing when called with nil' do
          policy = RoutePolicy.new(source_type: 'app', source_guid: app_guid)
          policy.source = nil
          expect(policy.source_type).to eq('app')
          expect(policy.source_guid).to eq(app_guid)
        end

        it 'sets source_type to nil for malformed input' do
          policy = RoutePolicy.new
          policy.source = 'garbage'
          expect(policy.source_type).to be_nil
        end
      end
    end

    describe 'validations' do
      it 'requires a selector' do
        policy = RoutePolicy.new(route:)
        expect(policy.valid?).to be false
        expect(policy.errors[:source_type]).to include(:presence)
      end

      it 'requires a route_id' do
        policy = RoutePolicy.new(source: 'cf:app:123')
        expect(policy.valid?).to be false
        expect(policy.errors[:route_id]).to include(:presence)
      end

      describe 'cf:any exclusivity' do
        it 'rejects cf:any when another policy already exists on the route' do
          create(:route_policy, source: "cf:app:#{app_guid}", route: route)
          policy = RoutePolicy.new(source: 'cf:any', route: route)

          expect(policy.valid?).to be false
          expect(policy.errors[:source]).to include("'cf:any' cannot coexist with other route policies on the same route")
        end

        it 'rejects a non-cf:any policy when a cf:any policy already exists on the route' do
          create(:route_policy, source: 'cf:any', route: route)
          policy = RoutePolicy.new(source: "cf:app:#{app_guid}", route: route)

          expect(policy.valid?).to be false
          expect(policy.errors[:source]).to include("cannot coexist with the existing 'cf:any' policy on this route")
        end

        it 'raises Sequel::ValidationFailed when saving a conflicting cf:any policy' do
          create(:route_policy, source: "cf:app:#{app_guid}", route: route)

          expect do
            create(:route_policy, source: 'cf:any', route: route)
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'allows multiple non-cf:any policies on the same route' do
          create(:route_policy, source: "cf:app:#{app_guid}", route: route)

          expect do
            create(:route_policy, source: "cf:app:#{SecureRandom.uuid}", route: route)
          end.not_to raise_error
        end

        it 'allows cf:any when the route has no other policies' do
          expect do
            create(:route_policy, source: 'cf:any', route: route)
          end.not_to raise_error
        end
      end
    end

    describe 'associations' do
      it 'belongs to a route' do
        policy = create(:route_policy, source: 'cf:app:123', route: route)
        expect(policy.route).to eq(route)
      end
    end

    describe 'columns' do
      it 'persists source_type for a typed source' do
        policy = create(:route_policy, source: "cf:app:#{app_guid}", route: route)
        expect(policy.source_type).to eq('app')
        expect(policy.source_guid).to eq(app_guid)
      end

      it 'persists source_type and empty source_guid for cf:any' do
        policy = create(:route_policy, source: 'cf:any', route: route)
        expect(policy.source_type).to eq('any')
        expect(policy.source_guid).to eq('')
      end
    end

    describe '#notify_diego' do
      let(:policy) { create(:route_policy, source: "cf:app:#{app_guid}", route: route) }

      it 'notifies the backend for each associated process' do
        process # force creation

        expect_any_instance_of(ProcessRouteHandler).to receive(:notify_backend_of_route_update).once

        policy.notify_diego
      end

      it 'does nothing when the route has no associated processes' do
        route_without_processes = create(:route, space:, domain:)
        policy_without_processes = create(:route_policy, source: "cf:app:#{app_guid}", route: route_without_processes)

        expect do
          policy_without_processes.notify_diego
        end.not_to raise_error
      end

      it 'does nothing when the route is nil' do
        policy_without_route = RoutePolicy.new(source: "cf:app:#{app_guid}")

        expect do
          policy_without_route.notify_diego
        end.not_to raise_error
      end
    end
  end
end
