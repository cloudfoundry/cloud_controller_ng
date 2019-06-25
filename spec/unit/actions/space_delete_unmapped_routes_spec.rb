require 'spec_helper'
require 'actions/space_delete_unmapped_routes'

module VCAP::CloudController
  RSpec.describe SpaceDeleteUnmappedRoutes do
    subject(:routes_delete) { SpaceDeleteUnmappedRoutes.new }

    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

    let(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }
    let(:app) { AppModel.make(space: space) }
    let(:domain) { PrivateDomain.make(owning_organization: org) }

    describe '#delete' do
      context 'when there are some mapped routes and some unmapped routes' do
        let!(:mapped_route) { Route.make(domain: domain, space: space, host: 'mapped') }
        let!(:destination) { RouteMappingModel.make(app: app, route: mapped_route) }
        let!(:unmapped_route_1) { Route.make(domain: domain, space: space, host: 'unmapped1') }
        let!(:unmapped_route_2) { Route.make(domain: domain, space: space, host: 'unmapped2') }

        it 'deletes only unmapped routes' do
          expect {
            subject.delete(space)
          }.to change { VCAP::CloudController::Route.count }.by(-2)

          expect { unmapped_route_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { unmapped_route_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      context 'when there are some bound routes and some unbound routes' do
        let!(:bound_route) { Route.make(domain: domain, space: space, host: 'bound') }
        let!(:service_instance) { ManagedServiceInstance.make(:routing, space: space) }
        let!(:_) { RouteBinding.make(service_instance: service_instance, route: bound_route) }
        let!(:unbound_route_1) { Route.make(domain: domain, space: space, host: 'unbound1') }
        let!(:unbound_route_2) { Route.make(domain: domain, space: space, host: 'unbound2') }

        it 'deletes only unbound routes' do
          expect {
            subject.delete(space)
          }.to change { VCAP::CloudController::Route.count }.by(-2)

          expect { unbound_route_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { unbound_route_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      context 'when there is a mix of bound and mapped routes' do
        let!(:service_instance) { ManagedServiceInstance.make(:routing, space: space) }

        let!(:bound_and_mapped_route) { Route.make(domain: domain, space: space, host: 'bound', path: '/mapped') }
        let!(:_0) { RouteBinding.make(service_instance: service_instance, route: bound_and_mapped_route) }
        let!(:_1) { RouteMappingModel.make(app: app, route: bound_and_mapped_route) }

        let!(:bound_and_unmapped_route) { Route.make(domain: domain, space: space, host: 'bound', path: '/unmapped') }
        let!(:_2) { RouteBinding.make(service_instance: service_instance, route: bound_and_unmapped_route) }

        let!(:unbound_and_unmapped_route) { Route.make(domain: domain, space: space, host: 'unbound', path: '/unmapped') }

        let!(:unbound_and_mapped_route) { Route.make(domain: domain, space: space, host: 'unbound', path: '/mapped') }
        let!(:_3) { RouteMappingModel.make(app: app, route: unbound_and_mapped_route) }

        it 'deletes only BOTH unmapped and unbound routes' do
          expect {
            subject.delete(space)
          }.to change { VCAP::CloudController::Route.count }.by(-1)

          expect { unbound_and_unmapped_route.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end
    end
  end
end
