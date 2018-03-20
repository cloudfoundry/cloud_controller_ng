require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingDelete do
    subject(:route_mapping_delete) { RouteMappingDelete.new(user_audit_info) }
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:user_email) { 'user_email' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space: space) }
    let(:route) { Route.make(space: space) }
    let!(:route_mapping) { RouteMappingModel.make(app: app, route: route, process_type: 'other', guid: 'go wild') }
    let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    before do
      allow(ProcessRouteHandler).to receive(:new).and_return(route_handler)
    end

    describe '#delete' do
      context 'when expected route mappings are present in the database' do
        it 'deletes the route from the app' do
          expect(app.reload.routes).not_to be_empty
          route_mapping_delete.delete(route_mapping)
          expect(app.reload.routes).to be_empty
        end

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

        it 'delegates to the route handler to update route information without process validation' do
          route_mapping_delete.delete(route_mapping)
          expect(route_handler).to have_received(:update_route_information).with(perform_validation: false)
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
              user_audit_info,
              route_mapping.guid,
              route_mapping.process_type
            )
          end
        end
      end

      context 'when expected route mappings are not present in the database' do
        before do
          route_mapping.destroy
        end

        it 'does no harm and gracefully continues' do
          expect { route_mapping_delete.delete(route_mapping) }.not_to raise_error
        end

        it 'deletes only present route mappings' do
          route_mapping_2 = RouteMappingModel.make app: app
          expect { route_mapping_delete.delete([route_mapping, route_mapping_2]) }.not_to raise_error
          expect(route_mapping_2.exists?).to be_falsey
        end

        it 'does not delegate to the route handler to update route information' do
          route_mapping_delete.delete(route_mapping)
          expect(route_handler).not_to have_received(:update_route_information)
        end

        describe 'recording events' do
          let(:event_repository) { instance_double(Repositories::AppEventRepository) }

          before do
            allow(Repositories::AppEventRepository).to receive(:new).and_return(event_repository)
            allow(event_repository).to receive(:record_unmap_route)
          end

          it 'does not record an event for un mapping a route to an app' do
            route_mapping_delete.delete(route_mapping)

            expect(event_repository).not_to have_received(:record_unmap_route)
          end
        end
      end
    end
  end
end
