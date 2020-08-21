require 'spec_helper'
require 'actions/service_route_binding_create'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceRouteBindingCreate do
      let(:space) { VCAP::CloudController::Space.make }
      let(:route_service_url) { 'https://route_service_url.com' }
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_service_instance_event)
        dbl
      end

      before do
        allow(Diego::Messenger).to receive(:new).and_return(messenger)
      end

      subject(:action) { described_class.new(event_repository) }

      describe 'preflight()' do
        context 'route is internal' do
          let(:domain) { VCAP::CloudController::SharedDomain.make(internal: true, name: 'my.domain.com') }
          let(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }

          it 'raises an error' do
            expect {
              action.preflight(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::UnprocessableCreate,
              'Route services cannot be bound to internal routes',
            )
          end
        end

        context 'route and service instance are in different spaces' do
          let(:route) { VCAP::CloudController::Route.make }

          it 'raises an error' do
            expect {
              action.preflight(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::UnprocessableCreate,
              'The service instance and the route are in different spaces',
            )
          end
        end

        context 'route binding already exists' do
          it 'raises an error' do
            VCAP::CloudController::RouteBinding.make(service_instance: service_instance, route: route)

            expect {
              action.preflight(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::RouteBindingAlreadyExists,
              'The route and service instance are already bound',
            )
          end
        end

        context 'route already bound to a different service instance' do
          it 'raises an error' do
            other_instance = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url)
            VCAP::CloudController::RouteBinding.make(service_instance: other_instance, route: route)

            expect {
              action.preflight(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::UnprocessableCreate,
              'A route may only be bound to a single service instance',
            )
          end
        end

        context 'service instance does not support route binding' do
          let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

          it 'raises an error' do
            expect {
              action.preflight(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::UnprocessableCreate,
              'This service instance does not support route binding',
            )
          end
        end
      end

      describe 'create()' do
        it 'creates and returns the route binding' do
          binding = action.create(service_instance, route)

          expect(binding).to eq(VCAP::CloudController::RouteBinding.first)
          expect(binding).not_to be_nil
          expect(binding.service_instance).to eq(service_instance)
          expect(binding.route).to eq(route)
          expect(binding.route_service_url).to eq(route_service_url)
        end

        it 'creates an audit event' do
          action.create(service_instance, route)

          expect(event_repository).to have_received(:record_service_instance_event).with(
            :bind_route,
            service_instance,
            { route_guid: route.guid },
          )
        end

        context 'route does not have app' do
          it 'does not notify diego' do
            action.create(service_instance, route)

            expect(messenger).not_to have_received(:send_desire_request)
          end
        end

        context 'route has app' do
          let(:process) { ProcessModelFactory.make(space: route.space, state: 'STARTED') }

          it 'notifies diego' do
            RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
            action.create(service_instance, route)

            expect(messenger).to have_received(:send_desire_request).with(process)
          end
        end
      end
    end
  end
end
