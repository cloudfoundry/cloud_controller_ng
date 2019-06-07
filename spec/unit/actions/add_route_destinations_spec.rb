require 'spec_helper'
require 'actions/add_route_destinations'

module VCAP::CloudController
  RSpec.describe AddRouteDestinations do
    subject(:add_destinations) { AddRouteDestinations }
    let(:message) { RouteAddDestinationsMessage.new(params) }
    let(:space) { Space.make }
    let(:app) { AppModel.make(guid: 'some-guid', space: space) }
    let(:app2) { AppModel.make(guid: 'some-other-guid', space: space) }
    let(:app_hash) do
      {
        app.guid => app,
        app2.guid => app2,
      }
    end
    let(:route) { Route.make }
    let(:ports) { [8080] }
    let!(:process1) { ProcessModel.make(:process, app: app, type: 'web', ports: ports, health_check_type: 'none') }
    let!(:process2) { ProcessModel.make(:process, app: app2, type: 'worker', ports: ports, health_check_type: 'none') }
    let(:process1_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }
    let(:process2_route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

    context 'when all destinations are valid' do
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app.guid,
                process: {
                  type: 'web'
                }
              }
            },
            {
              app: {
                guid: app2.guid,
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
          subject.add(message, route, app_hash)
        }.to change { RouteMappingModel.count }.by(2)
        route.reload
        expect(route.route_mappings[0].app_guid).to eq(app.guid)
        expect(route.route_mappings[0].process_type).to eq('web')
        expect(route.route_mappings[1].app_guid).to eq(app2.guid)
        expect(route.route_mappings[1].process_type).to eq('worker')
      end

      it 'delegates to the route handler to update route information' do
        subject.add(message, route, app_hash)

        expect(process1_route_handler).to have_received(:update_route_information)
        expect(process2_route_handler).to have_received(:update_route_information)
      end

      describe 'copilot integration' do
        before do
          allow(Copilot::Adapter).to receive(:map_route)
        end

        it 'delegates to the copilot handler to notify copilot' do
          expect {
            subject.add(message, route, app_hash)
            expect(Copilot::Adapter).to have_received(:map_route).with(route.route_mappings[0])
            expect(Copilot::Adapter).to have_received(:map_route).with(route.route_mappings[1])
          }.to change { RouteMappingModel.count }.by(2)
        end
      end
    end

    context 'when a fully equal destination already exists' do
      let!(:same_destination) { RouteMappingModel.make(
        app: app,
        route: route,
        app_port:  ProcessModel::DEFAULT_HTTP_PORT,
        process_type: 'web'
      )
      }

      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app.guid,
                process: {
                  type: 'web'
                }
              }
            }
          ]
        }
      end

      it 'doesnt add the new destination' do
        expect {
          subject.add(message, route, app_hash)
        }.to change { RouteMappingModel.count }.by(0)
      end
    end
  end
end
