require 'spec_helper'
require 'actions/update_route_destinations'

module VCAP::CloudController
  RSpec.describe UpdateRouteDestinations do
    subject(:update_destinations) { UpdateRouteDestinations }
    let(:message) { RouteUpdateDestinationsMessage.new(params) }
    let(:space) { Space.make }
    let(:app_model) { AppModel.make(guid: 'some-guid', space: space) }
    let(:app_model2) { AppModel.make(guid: 'some-other-guid', space: space) }
    let(:route) { Route.make }
    let(:ports) { [8080] }
    let!(:existing_destination) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app_model,
        route: route,
        process_type: 'existing',
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
      )
    end
    let!(:process1) { ProcessModel.make(:process, app: app_model, type: 'web', ports: ports, health_check_type: 'none') }
    let!(:process2) { ProcessModel.make(:process, app: app_model2, type: 'worker', ports: ports, health_check_type: 'none') }
    let!(:process3) { ProcessModel.make(:process, app: app_model, type: 'existing', ports: ports, health_check_type: 'none') }
    let(:process1_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
    let(:process2_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
    let(:process3_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: 'user-guid') }
    let(:route_event_repo) { instance_double(Repositories::RouteEventRepository) }

    describe '#add' do
      context 'when all destinations are valid' do
        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: app_model.guid,
                  process: {
                    type: 'web'
                  }
                }
              },
              {
                app: {
                  guid: app_model2.guid,
                  process: {
                    type: 'worker'
                  }
                }
              }
            ]
          }
        end

        before do
          allow(ProcessRouteHandler).to receive(:new).with(process1).and_return(process1_route_handler)
          allow(ProcessRouteHandler).to receive(:new).with(process2).and_return(process2_route_handler)
        end

        it 'adds all the destinations and updates the routing' do
          expect {
            subject.add(message, route, user_audit_info)
          }.to change { RouteMappingModel.count }.by(2)
          route.reload
          mappings = route.route_mappings.collect { |rm| { app_guid: rm.app_guid, process_type: rm.process_type } }
          expect(mappings).to contain_exactly(
            { app_guid: app_model.guid, process_type: 'web' },
            { app_guid: app_model.guid, process_type: 'existing' },
            { app_guid: app_model2.guid, process_type: 'worker' },
          )
        end

        it 'delegates to the route handler to update route information' do
          subject.add(message, route, user_audit_info)

          expect(process1_route_handler).to have_received(:update_route_information)
          expect(process2_route_handler).to have_received(:update_route_information)
        end

        describe 'audit events' do
          before do
            allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
            allow(route_event_repo).to receive(:record_route_map)
            subject.add(message, route, user_audit_info)
          end

          it 'records an audit event for each new route mapping' do
            route.reload
            route.route_mappings.reject { |rm| rm.process_type == 'existing' }.each do |rm|
              expect(route_event_repo).to have_received(:record_route_map).once.with(rm, user_audit_info)
            end
          end
        end

        describe 'copilot integration' do
          before do
            allow(Copilot::Adapter).to receive(:map_route)
          end

          it 'delegates to the copilot handler to notify copilot' do
            expect {
              subject.add(message, route, user_audit_info)
              expect(Copilot::Adapter).to have_received(:map_route).with(have_attributes(process_type: 'web'))
              expect(Copilot::Adapter).to have_received(:map_route).with(have_attributes(process_type: 'worker'))
              expect(Copilot::Adapter).not_to have_received(:map_route).with(have_attributes(process_type: 'existing'))
            }.to change { RouteMappingModel.count }.by(2)
          end
        end
      end

      context 'when a fully equal destination already exists' do
        let!(:same_destination) do
          RouteMappingModel.make(
            app: app_model,
            route: route,
            app_port:  ProcessModel::DEFAULT_HTTP_PORT,
            process_type: 'web'
          )
        end

        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: app_model.guid,
                  process: {
                    type: 'web'
                  }
                }
              }
            ]
          }
        end

        it "doesn't add the new destination" do
          expect {
            subject.add(message, route, user_audit_info)
          }.to change { RouteMappingModel.count }.by(0)
        end

        describe 'audit events' do
          before do
            allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
            allow(route_event_repo).to receive(:record_route_map)
            subject.replace(message, route, user_audit_info)
          end

          it 'does not record an audit event for an existing route mapping' do
            expect(route_event_repo).not_to have_received(:record_route_map)
          end
        end
      end
    end

    describe '#replace' do
      context 'when all destinations are valid' do
        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: app_model.guid,
                  process: {
                    type: 'web'
                  }
                }
              },
              {
                app: {
                  guid: app_model2.guid,
                  process: {
                    type: 'worker'
                  }
                }
              }
            ]
          }
        end

        before do
          allow(ProcessRouteHandler).to receive(:new).with(process1).and_return(process1_route_handler)
          allow(ProcessRouteHandler).to receive(:new).with(process2).and_return(process2_route_handler)
          allow(ProcessRouteHandler).to receive(:new).with(process3).and_return(process3_route_handler)
        end

        it 'replaces all the route_mappings' do
          expect {
            subject.replace(message, route, user_audit_info)
          }.to change { RouteMappingModel.count }.by(1)
          route.reload
          mappings = route.route_mappings.collect { |rm| { app_guid: rm.app_guid, process_type: rm.process_type } }
          expect(mappings).to contain_exactly(
            { app_guid: app_model.guid, process_type: 'web' },
            { app_guid: app_model2.guid, process_type: 'worker' },
          )
        end

        it 'delegates to the route handler to update route information' do
          subject.replace(message, route, user_audit_info)

          expect(process1_route_handler).to have_received(:update_route_information)
          expect(process2_route_handler).to have_received(:update_route_information)
          expect(process3_route_handler).to have_received(:update_route_information)
        end

        describe 'audit events' do
          before do
            allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
            allow(route_event_repo).to receive(:record_route_map)
            subject.replace(message, route, user_audit_info)
          end

          it 'records an audit event for each new route mapping' do
            route.reload
            route.route_mappings.each do |rm|
              expect(route_event_repo).to have_received(:record_route_map).once.with(rm, user_audit_info)
            end
          end
        end

        describe 'copilot integration' do
          before do
            allow(Copilot::Adapter).to receive(:map_route)
            allow(Copilot::Adapter).to receive(:unmap_route)
          end

          it 'delegates to the copilot handler to notify copilot' do
            expect {
              subject.replace(message, route, user_audit_info)
              expect(Copilot::Adapter).to have_received(:map_route).with(have_attributes(process_type: 'web'))
              expect(Copilot::Adapter).to have_received(:map_route).with(have_attributes(process_type: 'worker'))
              expect(Copilot::Adapter).to have_received(:unmap_route).with(have_attributes(process_type: 'existing'))
            }.to change { RouteMappingModel.count }.by(1)
          end
        end
      end

      context 'when a fully equal destination already exists' do
        let!(:same_destination) do
          RouteMappingModel.make(
            app: app_model,
            route: route,
            app_port:  ProcessModel::DEFAULT_HTTP_PORT,
            process_type: 'web'
          )
        end

        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: app_model.guid,
                  process: {
                    type: 'web'
                  }
                }
              }
            ]
          }
        end

        it 'doesnt replace the new destination' do
          expect {
            subject.replace(message, route, user_audit_info)
          }.to change { RouteMappingModel.count }.by(-1)
        end

        describe 'audit events' do
          before do
            allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
            allow(route_event_repo).to receive(:record_route_map)
            subject.replace(message, route, user_audit_info)
          end

          it 'does not record an audit event for a new route mapping' do
            expect(route_event_repo).not_to have_received(:record_route_map)
          end
        end
      end
    end

    describe '#delete' do
      it 'deletes the route mapping record' do
        expect {
          subject.delete(existing_destination, route, user_audit_info)
        }.to change { RouteMappingModel.count }.by(-1)
        expect { existing_destination.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'copilot integration' do
        before do
          allow(Copilot::Adapter).to receive(:unmap_route)
        end

        it 'delegates to the copilot handler to notify copilot' do
          subject.delete(existing_destination, route, user_audit_info)
          expect(Copilot::Adapter).to have_received(:unmap_route).with(existing_destination)
        end
      end

      describe 'diego integration' do
        let(:fake_process_route_handler) { instance_double(ProcessRouteHandler) }

        before do
          allow(ProcessRouteHandler).to receive(:new).with(process3).and_return(fake_process_route_handler)
          allow(fake_process_route_handler).to receive(:update_route_information)
        end

        it 'updates route information for route processes' do
          subject.delete(existing_destination, route, user_audit_info)
          expect(fake_process_route_handler).to have_received(:update_route_information).
            with(perform_validation: false)
        end
      end
    end
  end
end
