require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteDelete do
    subject(:route_delete_action) do
      RouteDelete.new(
        app_event_repository: app_event_repository,
        route_event_repository: route_event_repository,
        user_audit_info: user_audit_info
      )
    end

    let(:app_event_repository) { instance_double(Repositories::AppEventRepository, record_unmap_route: nil) }
    let(:route_event_repository) { instance_double(Repositories::RouteEventRepository, record_route_delete_request: nil) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid', user_email: 'user-email') }
    let(:recursive) { false }
    let!(:route) { Route.make }
    let(:route_resource_manager) { instance_double(Kubernetes::RouteResourceManager) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:route_resource_manager).and_return(route_resource_manager)
      allow(route_resource_manager).to receive(:delete_route)
    end

    describe 'delete_unmapped_route' do
      it 'deletes the route' do
        route_delete_action.delete_unmapped_route(route: route)

        expect(route.exists?).to eq(false)
      end

      it 'creates a route delete audit event' do
        route_delete_action.delete_unmapped_route(route: route)

        expect(route_event_repository).to have_received(:record_route_delete_request).with(route, user_audit_info, false)
      end

      context 'when there are route mappings' do
        it 'does not deletes the mappings or route' do
          route_mapping = RouteMappingModel.make(route: route)
          route_mapping_2 = RouteMappingModel.make(route: route)

          route_delete_action.delete_unmapped_route(route: route)

          expect(route.exists?).to eq(true)
          expect(route_mapping.exists?).to eq(true)
          expect(route_mapping_2.exists?).to eq(true)
        end
      end

      context 'when there is a service binding' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }

        it 'does not delete the route' do
          route_delete_action.delete_unmapped_route(route: route)

          expect(route.exists?).to eq(true)
          expect(route_binding.exists?).to eq(true)
        end
      end

      context 'when a foreign key violation occurs' do
        before do
          allow(Route).to receive(:where).and_raise(Sequel::ForeignKeyConstraintViolation)
        end

        it 'does not delete the route' do
          route_delete_action.delete_unmapped_route(route: route)
          expect(route.exists?).to eq(true)
        end
      end
    end

    describe 'delete_sync' do
      it 'deletes the route' do
        route_delete_action.delete_sync(route: route, recursive: recursive)

        expect(route.exists?).to be_falsey
      end

      it 'creates a route delete audit event' do
        route_delete_action.delete_sync(route: route, recursive: recursive)

        expect(route_event_repository).to have_received(:record_route_delete_request).with(route, user_audit_info, false)
      end

      context 'when there are route mappings' do
        let!(:route_mapping) { RouteMappingModel.make route: route }
        let!(:route_mapping_2) { RouteMappingModel.make route: route }

        it 'deletes the mappings' do
          route_delete_action.delete_sync(route: route, recursive: recursive)

          expect(route_mapping.exists?).to be_falsey
          expect(route_mapping_2.exists?).to be_falsey
        end

        it 'creates an unmap-route audit event for each mapping' do
          route_delete_action.delete_sync(route: route, recursive: recursive)

          expect(app_event_repository).to have_received(:record_unmap_route).with(user_audit_info, route_mapping).once
          expect(app_event_repository).to have_received(:record_unmap_route).with(user_audit_info, route_mapping_2).once
        end
      end

      context 'when there are route services bound to the route' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }

        context 'and it is a recursive delete' do
          let(:recursive) { true }

          before do
            stub_unbind(route_binding)
          end

          it 'deletes the route and associated binding' do
            route_delete_action.delete_sync(route: route, recursive: recursive)

            expect(Route.find(guid: route.guid)).not_to be
            expect(RouteBinding.find(guid: route_binding.guid)).not_to be
          end
        end

        context 'and it is not a recursive delete' do
          it 'raises an error and does not delete anything' do
            expect {
              route_delete_action.delete_sync(route: route, recursive: recursive)
            }.to raise_error(RouteDelete::ServiceInstanceAssociationError)
          end
        end
      end

      context 'when targeting a Kubernetes API' do
        before do
          TestConfig.override(kubernetes: { host_url: 'https://kubernetes.example.com' })
          allow(CloudController::DependencyLocator.instance).to receive(:route_resource_manager).and_return(route_resource_manager)
          allow(route_resource_manager).to receive(:delete_route)
        end

        it 'deletes the route resource in Kubernetes' do
          expect {
            route_delete_action.delete_sync(route: route, recursive: false)
            expect(route_resource_manager).to have_received(:delete_route)
          }.to change { Route.count }.by(-1)
        end
      end

      context 'when not targeting a Kubernetes API' do
        before do
          TestConfig.override(
            kubernetes: {}
          )
        end
        it 'does not delete the route resource in Kubernetes' do
          route_delete_action.delete_sync(route: route, recursive: false)
          expect(route_resource_manager).not_to have_received(:delete_route)
        end
      end
    end

    describe 'delete_async' do
      it 'returns a delete job for the route' do
        job = route_delete_action.delete_async(route: route, recursive: false)

        expect(job).to be_a_fully_wrapped_job_of(Jobs::Runtime::ModelDeletion)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(route.exists?).to be_falsey
      end
    end
  end
end
