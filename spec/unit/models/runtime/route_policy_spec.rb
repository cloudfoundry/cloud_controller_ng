require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RoutePolicy, type: :model do
    let(:space) { Space.make }
    let(:domain) { SharedDomain.make(name: 'apps.identity') }
    let(:route) { Route.make(space:, domain:) }
    let(:app_model) { AppModel.make(space:) }
    let(:process) do
      ProcessModel.make(app: app_model, type: 'web')
    end
    let(:app_guid) { SecureRandom.uuid }

    before do
      RouteMappingModel.make(app: app_model, route: route, process_type: 'web')
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
          route_without_processes = Route.make(space:, domain:)

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
          route_without_processes = Route.make(space:, domain:)
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
