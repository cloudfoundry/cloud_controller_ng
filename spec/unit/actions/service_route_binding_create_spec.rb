require 'db_spec_helper'
require 'actions/service_route_binding_create'
require 'support/shared_examples/v3_service_binding_create'

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
          it 'returns a route binding precursor' do
            precursor = action.precursor(service_instance, route)
            expect(precursor).to be_a(RouteBinding)
            expect(precursor).to eq(RouteBinding.first)
            expect(precursor.service_instance).to eq(service_instance)
            expect(precursor.route).to eq(route)
            expect(precursor.route_service_url).to be_nil
            expect(precursor.last_operation.type).to eq('create')
            expect(precursor.last_operation.state).to eq('in progress')
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

          context 'when there is an operation in progress for the service instance' do
            it 'raises an error' do
              service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

              expect {
                action.precursor(service_instance, route)
              }.to raise_error(
                ServiceRouteBindingCreate::UnprocessableCreate,
                'There is an operation in progress for the service instance'
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

      context '#bind' do
        let(:precursor) { action.precursor(service_instance, route) }
        let(:binding_model) { RouteBinding }
        let(:bind_response) { { binding: { route_service_url: route_service_url } } }

        it_behaves_like 'service binding creation', RouteBinding

        describe 'route specific behaviour' do
          let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }

          before do
            allow(Diego::Messenger).to receive(:new).and_return(messenger)
          end

          RSpec.shared_examples '#route bind' do
            it 'creates and returns the route binding' do
              action.bind(precursor)

              binding = precursor.reload
              expect(binding).to eq(RouteBinding.first)
              expect(binding.service_instance).to eq(service_instance)
              expect(binding.route).to eq(route)
              expect(binding.route_service_url).to eq(route_service_url)
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('succeeded')
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
            let(:service_offering) { Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
            let(:service_plan) { ServicePlan.make(service: service_offering) }
            let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like '#route bind'
          end

          context 'user-provided service instance' do
            let(:route_service_url) { 'https://route_service_url.com' }
            let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

            it_behaves_like '#route bind'
          end
        end
      end

      describe '#poll' do
        let(:binding) { action.precursor(service_instance, route) }
        let(:fetch_binding_response) { { route_service_url: route_service_url } }

        it_behaves_like 'polling service binding creation'

        describe 'route specific behaviour' do
          let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }
          let(:service_offering) { Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
          let(:broker_provided_operation) { Sham.guid }
          let(:bind_response) { { async: true, operation: broker_provided_operation } }
          let(:description) { Sham.description }
          let(:state) { 'in progress' }
          let(:fetch_last_operation_response) do
            {
              last_operation: {
                state: state,
                description: description,
              },
            }
          end
          let(:broker_client) do
            instance_double(
              VCAP::Services::ServiceBrokers::V2::Client,
              {
                bind: bind_response,
                fetch_service_binding_last_operation: fetch_last_operation_response,
                fetch_service_binding: fetch_binding_response,
              }
            )
          end

          before do
            allow(Diego::Messenger).to receive(:new).and_return(messenger)
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)

            action.bind(binding, accepts_incomplete: true)
          end

          context 'response says complete' do
            let(:description) { Sham.description }
            let(:state) { 'succeeded' }

            it 'fetches the service binding and updates the route_services_url' do
              action.poll(binding)

              expect(broker_client).to have_received(:fetch_service_binding).with(binding)

              binding.reload
              expect(binding.route_service_url).to eq(route_service_url)
            end

            it 'creates an audit event' do
              action.poll(binding)

              expect(event_repository).to have_received(:record_service_instance_event).with(
                :bind_route,
                service_instance,
                { route_guid: route.guid },
              )
            end

            context 'route does not have app' do
              it 'does not notify diego' do
                action.poll(binding)

                expect(messenger).not_to have_received(:send_desire_request)
              end
            end

            context 'route has app' do
              let(:process) { ProcessModelFactory.make(space: route.space, state: 'STARTED') }

              it 'notifies diego' do
                RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
                action.poll(binding)

                expect(messenger).to have_received(:send_desire_request).with(process)
              end
            end
          end

          context 'response says in progress' do
            it 'does not notify diego or create an audit event' do
              action.poll(binding)

              expect(messenger).not_to have_received(:send_desire_request)
              expect(event_repository).not_to have_received(:record_service_instance_event)
            end
          end

          context 'response says failed' do
            let(:state) { 'failed' }
            it 'does not notify diego or create an audit event' do
              expect{ action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

              expect(messenger).not_to have_received(:send_desire_request)
              expect(event_repository).not_to have_received(:record_service_instance_event)
            end
          end
        end
      end
    end
  end
end
