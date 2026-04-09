require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteAccessRule, type: :model do
    let(:space) { Space.make }
    let(:domain) { SharedDomain.make(name: 'apps.identity') }
    let(:route) { Route.make(space: space, domain: domain) }
    let(:process) { ProcessModelFactory.make(space: space) }
    let(:app_guid) { SecureRandom.uuid }

    before do
      RouteMappingModel.make(app: process, route: route, process_type: 'web')
    end

    describe 'validations' do
      it 'requires a name' do
        rule = RouteAccessRule.new(selector: 'cf:app:123', route: route)
        expect(rule.valid?).to be false
        expect(rule.errors[:name]).to include("can't be blank")
      end

      it 'requires a selector' do
        rule = RouteAccessRule.new(name: 'test-rule', route: route)
        expect(rule.valid?).to be false
        expect(rule.errors[:selector]).to include("can't be blank")
      end

      it 'requires a route_id' do
        rule = RouteAccessRule.new(name: 'test-rule', selector: 'cf:app:123')
        expect(rule.valid?).to be false
        expect(rule.errors[:route_id]).to include("can't be blank")
      end
    end

    describe 'associations' do
      it 'belongs to a route' do
        rule = RouteAccessRule.create(
          name: 'test-rule',
          selector: 'cf:app:123',
          route: route
        )
        expect(rule.route).to eq(route)
      end
    end

    describe 'callbacks' do
      describe 'after_create' do
        it 'touches associated processes to trigger Diego sync' do
          initial_updated_at = process.updated_at

          # Sleep to ensure timestamp difference
          sleep 0.1

          RouteAccessRule.create(
            name: 'test-rule',
            selector: "cf:app:#{app_guid}",
            route: route
          )

          process.reload
          expect(process.updated_at).to be > initial_updated_at
        end

        it 'does not fail if route has no associated processes' do
          route_without_processes = Route.make(space: space, domain: domain)

          expect {
            RouteAccessRule.create(
              name: 'test-rule',
              selector: "cf:app:#{app_guid}",
              route: route_without_processes
            )
          }.not_to raise_error
        end
      end

      describe 'after_destroy' do
        it 'touches associated processes to trigger Diego sync' do
          rule = RouteAccessRule.create(
            name: 'test-rule',
            selector: "cf:app:#{app_guid}",
            route: route
          )

          process.reload
          initial_updated_at = process.updated_at

          # Sleep to ensure timestamp difference
          sleep 0.1

          rule.destroy

          process.reload
          expect(process.updated_at).to be > initial_updated_at
        end

        it 'does not fail if route has no associated processes' do
          route_without_processes = Route.make(space: space, domain: domain)
          rule = RouteAccessRule.create(
            name: 'test-rule',
            selector: "cf:app:#{app_guid}",
            route: route_without_processes
          )

          expect {
            rule.destroy
          }.not_to raise_error
        end
      end
    end
  end
end
