require 'spec_helper'
require 'actions/route_delete'

module VCAP::CloudController
  RSpec.describe RouteDeleteAction do
    subject(:route_delete) { RouteDeleteAction.new }
    let(:space) { VCAP::CloudController::Space.make }

    describe '#delete' do
      let!(:route) { Route.make }

      it 'deletes the route record' do
        expect {
          route_delete.delete([route])
        }.to change { Route.count }.by(-1)
        expect { route.refresh }.to raise_error Sequel::Error, 'Record not found'
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
