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
        let!(:route_label) do
          VCAP::CloudController::RouteLabelModel.make(
            resource_guid: route.guid,
            key_prefix: 'pfx.com',
            key_name: 'potato',
            value: 'baked'
          )
        end

        let!(:route_annotation) do
          VCAP::CloudController::RouteAnnotationModel.make(
            resource_guid: route.guid,
            key: 'contacts',
            value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)'
          )
        end
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

        it 'deletes associated metadata labels' do
          expect {
            route_delete.delete([route])
          }.to change { RouteLabelModel.count }.by(-1)
          expect(RouteLabelModel.count).to eq 0
          expect(route.exists?).to be_falsey
        end

        it 'deletes associated metadata labels' do
          expect {
            route_delete.delete([route])
          }.to change { RouteAnnotationModel.count }.by(-1)
          expect(RouteAnnotationModel.count).to eq 0
          expect(route.exists?).to be_falsey
        end
      end
    end
  end
end
