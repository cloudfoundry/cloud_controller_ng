require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingDelete do
    subject(:route_mapping_delete) { described_class.new(user, user_email) }
    let(:user) { User.make }
    let(:user_email) { 'user_email' }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space: space) }
    let(:route) { Route.make(space: space) }
    let!(:route_mapping) { RouteMappingModel.create(app: app, route: route, process_type: 'other') }
    let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    before do
      allow(ProcessRouteHandler).to receive(:new).and_return(route_handler)
    end

    describe '#delete' do
      it 'can delete a single route mapping' do
        route_mapping_delete.delete(route_mapping)
        expect(route_mapping.exists?).to be_falsey
      end

      it 'can delete multiple route mappings' do
        route_mapping_2 = RouteMappingModel.make app: app
        route_mapping_delete.delete([route_mapping, route_mapping_2])
        expect(route_mapping.exists?).to be_falsey
        expect(route_mapping_2.exists?).to be_falsey
      end

      it 'deletes the route from the app' do
        expect(app.reload.routes).not_to be_empty
        route_mapping_delete.delete(route_mapping)
        expect(app.reload.routes).to be_empty
      end

      it 'delegates to the route handler to update route information' do
        route_mapping_delete.delete(route_mapping)
        expect(route_handler).to have_received(:update_route_information)
      end

      describe 'recording events' do
        let(:event_repository) { instance_double(Repositories::AppEventRepository) }

        before do
          allow(Repositories::AppEventRepository).to receive(:new).and_return(event_repository)
          allow(event_repository).to receive(:record_unmap_route)
        end

        it 'records an event for un mapping a route to an app' do
          route_mapping_delete.delete(route_mapping)

          expect(event_repository).to have_received(:record_unmap_route).with(
            app,
            route,
            user.guid,
            user_email,
            route_mapping: route_mapping
          )
        end
      end
    end
  end
end
