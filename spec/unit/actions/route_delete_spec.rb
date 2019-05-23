require 'spec_helper'
require 'actions/route_delete'

module VCAP::CloudController
  RSpec.describe RouteDeleteAction do
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:route_event_repo) { instance_double(Repositories::RouteEventRepository) }
    let(:space) { Space.make }

    subject(:route_delete) { RouteDeleteAction.new(user_audit_info) }

    describe '#delete' do
      let!(:route) { Route.make }

      before do
        allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
        allow(route_event_repo).to receive(:record_route_delete_request)
      end

      it 'deletes the route record' do
        expect {
          route_delete.delete([route])
        }.to change { Route.count }.by(-1)
        expect { route.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'audit events' do
        it 'records an audit event' do
          route_delete.delete([route])
          expect(route_event_repo).to have_received(:record_route_delete_request).with(route, user_audit_info, true)
        end
      end

      describe 'recursive deletion' do
        let(:app) { AppModel.make }
        let(:route) { Route.make(space: space, host: 'test') }
        let(:service_instance) { ManagedServiceInstance.make(:routing, space: space) }
        let!(:route_binding) { RouteBinding.make(route: route, service_instance: service_instance) }
        let!(:route_mapping) { RouteMappingModel.make(app: app, route: route, app_port: 8080) }

        before do
          stub_unbind(route_binding)
        end

        it 'deletes associated route mappings' do
          expect {
            route_delete.delete([route])
          }.to change { RouteMappingModel.count }.by(-1)
          expect(route.exists?).to be_falsey
          expect(route_mapping.exists?).to be_falsey
          expect(route.exists?).to be_falsey
        end

        it 'deletes associated route bindings' do
          expect {
            route_delete.delete([route])
          }.to change { RouteBinding.count }.by(-1)
          expect(route_binding.exists?).to be_falsey
          expect(route.exists?).to be_falsey
        end
      end
    end
  end
end
