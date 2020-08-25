require 'spec_helper'
require 'actions/service_route_binding_create'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceRouteBindingCreate do
      let(:space) { Space.make }
      let(:route) { Route.make(space: space) }
      let(:route_service_url) { 'https://route_service_url.com' }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_service_instance_event)
        dbl
      end

      subject(:action) { described_class.new(event_repository) }

      describe '#precursor' do
        RSpec.shared_examples '#precursor' do
          it 'returns a route precursor' do
            precursor = action.precursor(service_instance, route)
            expect(precursor).to be_a(RouteBinding)
            expect(precursor).to eq(RouteBinding.first)
            expect(precursor.service_instance).to be(service_instance)
            expect(precursor.route).to be(route)
            expect(precursor.route_service_url).to be_nil
          end

          context 'route is internal' do
            let(:domain) { SharedDomain.make(internal: true, name: 'my.domain.com') }
            let(:route) { Route.make(domain: domain, space: space) }

            it 'raises an error' do
              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::UnprocessableCreate,
                'Route services cannot be bound to internal routes',
              )
            end
          end

          context 'route and service instance are in different spaces' do
            let(:route) { Route.make }

            it 'raises an error' do
              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::UnprocessableCreate,
                'The service instance and the route are in different spaces',
              )
            end
          end

          context 'route binding already exists' do
            it 'raises an error' do
              RouteBinding.make(service_instance: service_instance, route: route)

              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::RouteBindingAlreadyExists,
                'The route and service instance are already bound',
              )
            end
          end

          context 'route already bound to a different service instance' do
            it 'raises an error' do
              other_instance = UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url)
              RouteBinding.make(service_instance: other_instance, route: route)

              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::UnprocessableCreate,
                'A route may only be bound to a single service instance',
              )
            end
          end
        end

        RSpec.shared_examples '#precursor for non-route service instance' do
          it 'raises an error' do
            expect {
              action.precursor(service_instance, route)
            }.to raise_error(
              ServiceRouteBindingCreate::UnprocessableCreate,
              'This service instance does not support route binding',
            )
          end
        end

        context 'managed service instance' do
          let(:service_offering) { Service.make(requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

          it_behaves_like '#precursor'

          context 'service instance not a route service' do
            let(:service_instance) { ManagedServiceInstance.make(space: space) }

            it_behaves_like '#precursor for non-route service instance'
          end

          context 'service instance not bindable' do
            let(:service_offering) { Service.make(bindable: false, requires: ['route_forwarding']) }

            it 'raises an error' do
              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::UnprocessableCreate,
                'This service instance does not support binding',
              )
            end
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

          it_behaves_like '#precursor'

          context 'service instance not a route service' do
            let(:service_instance) { UserProvidedServiceInstance.make }

            it_behaves_like '#precursor for non-route service instance'
          end
        end
      end

      describe '#bind' do
        let(:precursor) { action.precursor(service_instance, route) }
        let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }

        before do
          allow(Diego::Messenger).to receive(:new).and_return(messenger)
        end

        RSpec.shared_examples '#bind' do
          it 'creates and returns the route binding' do
            action.bind(precursor)

            binding = precursor.reload
            expect(binding).to eq(RouteBinding.first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.route).to eq(route)
            expect(binding.route_service_url).to eq(route_service_url)
          end

          it 'creates an audit event' do
            action.bind(precursor)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :bind_route,
              service_instance,
              { route_guid: route.guid },
            )
          end

          context 'route does not have app' do
            it 'does not notify diego' do
              action.bind(precursor)

              expect(messenger).not_to have_received(:send_desire_request)
            end
          end

          context 'route has app' do
            let(:process) { ProcessModelFactory.make(space: route.space, state: 'STARTED') }

            it 'notifies diego' do
              RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
              action.bind(precursor)

              expect(messenger).to have_received(:send_desire_request).with(process)
            end
          end
        end

        context 'managed service instance' do
          let(:service_offering) { Service.make(requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
          let(:bind_response) { { binding: { route_service_url: route_service_url } } }
          let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
          end

          it_behaves_like '#bind'

          context 'parameters are specified' do
            it 'sends the parameters to the broker client' do
              action.bind(precursor, parameters: { foo: 'bar' })

              expect(broker_client).to have_received(:bind).with(precursor, arbitrary_parameters: { foo: 'bar' })
            end
          end
        end

        context 'user-provided service instance' do
          let(:route_service_url) { 'https://route_service_url.com' }
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

          it_behaves_like '#bind'
        end
      end
    end
  end
end
