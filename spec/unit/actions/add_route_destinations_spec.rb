require 'spec_helper'
require 'actions/add_route_destinations'

module VCAP::CloudController
  RSpec.describe AddRouteDestinations do
    subject(:add_destinations) { AddRouteDestinations }
    let(:message) { RouteAddDestinationsMessage.new(params) }
    let(:space) { Space.make }
    let(:app) { AppModel.make(guid: 'some-guid', space: space) }
    let(:app2) { AppModel.make(guid: 'some-other-guid', space: space) }
    let(:route) { Route.make }
    let(:route_handler) { instance_double(ProcessRouteHandler, update_route_information: nil) }

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

      it 'adds all the destinations and updates the routing' do
        expect {
          subject.add(message, route)
        }.to change { RouteMappingModel.count }.by(2)
        route.reload
        expect(route.route_mappings[0].app_guid).to eq(app.guid)
        expect(route.route_mappings[0].process_type).to eq('web')
        expect(route.route_mappings[1].app_guid).to eq(app2.guid)
        expect(route.route_mappings[1].process_type).to eq('worker')
      end

      it 'delegates to the route handler to update route information' do
          subject.add(message, route)
        expect(route_handler).to have_received(:update_route_information)
      end

      describe 'copilot integration' do
        before do
          allow(Copilot::Adapter).to receive(:map_route)
        end

        it 'delegates to the copilot handler to notify copilot' do
          expect {
            subject.add(message, route)
            expect(Copilot::Adapter).to have_received(:map_route).with(route_mapping)
          }.to change { RouteMappingModel.count }.by(1)
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
          subject.add(message, route)
        }.to change { RouteMappingModel.count }.by(0)
      end
    end
  end
end
