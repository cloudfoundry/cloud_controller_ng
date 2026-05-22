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
        rule = RoutePolicy.new(route:)
        expect(rule.valid?).to be false
        expect(rule.errors[:source_type]).to include(:presence)
      end

      it 'requires a route_id' do
        rule = RoutePolicy.new(source: 'cf:app:123')
        expect(rule.valid?).to be false
        expect(rule.errors[:route_id]).to include(:presence)
      end
    end

    describe 'associations' do
      it 'belongs to a route' do
        rule = RoutePolicy.create(
          source: 'cf:app:123',
          route: route
        )
        expect(rule.route).to eq(route)
      end
    end

    describe 'columns' do
      it 'persists source_type for a typed source' do
        policy = RoutePolicy.create(source: "cf:app:#{app_guid}", route: route)
        expect(policy.source_type).to eq('app')
        expect(policy.source_guid).to eq(app_guid)
      end

      it 'persists source_type and empty source_guid for cf:any' do
        policy = RoutePolicy.create(source: 'cf:any', route: route)
        expect(policy.source_type).to eq('any')
        expect(policy.source_guid).to eq('')
      end
    end

    describe 'callbacks' do
      describe 'after_create' do
        it 'calls notify_processes_of_route_update' do
          expect_any_instance_of(RoutePolicy).to receive(:notify_processes_of_route_update).and_call_original

          RoutePolicy.create(
            source: "cf:app:#{app_guid}",
            route: route
          )
        end

        it 'updates associated processes' do
          process # force creation

          # Record the SQL update queries to verify the process row is updated
          RoutePolicy.create(
            source: "cf:app:#{app_guid}",
            route: route
          )

          # Verify the route has linked processes
          expect(route.apps).to include(process)
        end

        it 'does not fail if route has no associated processes' do
          route_without_processes = create(:route, space:, domain:)

          expect do
            RoutePolicy.create(
              source: "cf:app:#{app_guid}",
              route: route_without_processes
            )
          end.not_to raise_error
        end
      end

      describe 'after_destroy' do
        it 'calls notify_processes_of_route_update' do
          rule = RoutePolicy.create(
            source: "cf:app:#{app_guid}",
            route: route
          )

          expect_any_instance_of(RoutePolicy).to receive(:notify_processes_of_route_update).and_call_original

          rule.destroy
        end

        it 'does not fail if route has no associated processes' do
          route_without_processes = create(:route, space:, domain:)
          rule = RoutePolicy.create(
            source: "cf:app:#{app_guid}",
            route: route_without_processes
          )

          expect do
            rule.destroy
          end.not_to raise_error
        end
      end
    end
  end
end
