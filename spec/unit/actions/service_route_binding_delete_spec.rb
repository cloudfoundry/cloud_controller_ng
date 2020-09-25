require 'spec_helper'
require 'actions/service_route_binding_delete'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceRouteBindingDelete do
      let(:space) { Space.make }
      let(:route) { Route.make(space: space) }
      let(:route_service_url) { 'https://route_service_url.com' }
      let(:route_binding) do
        VCAP::CloudController::RouteBinding.new.save_with_new_operation(
          { service_instance: service_instance, route: route, route_service_url: route_service_url },
          { type: 'create', state: 'successful' }
        )
      end

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_service_instance_event)
        dbl
      end
      let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }

      before do
        allow(Diego::Messenger).to receive(:new).and_return(messenger)
      end

      subject(:action) { described_class.new(event_repository) }

      describe '#delete' do
        RSpec.shared_examples 'successful delete' do
          it 'deletes the binding' do
            action.delete(route_binding, async_allowed: async_allowed)

            expect(RouteBinding.all).to be_empty
          end

          it 'creates an audit event' do
            action.delete(route_binding, async_allowed: async_allowed)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :unbind_route,
              service_instance,
              { route_guid: route.guid },
            )
          end

          it 'says the the delete is complete' do
            result = action.delete(route_binding, async_allowed: async_allowed)
            expect(result).to be(described_class::DeleteComplete)
          end

          context 'route does not have app' do
            it 'does not notify diego' do
              action.delete(route_binding, async_allowed: async_allowed)

              expect(messenger).not_to have_received(:send_desire_request)
            end
          end

          context 'route has app' do
            let(:process) { ProcessModelFactory.make(space: route.space, state: 'STARTED') }

            it 'notifies diego' do
              RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
              action.delete(route_binding, async_allowed: async_allowed)

              expect(messenger).to have_received(:send_desire_request).with(process)
            end
          end
        end

        context 'managed service instance' do
          let(:service_offering) { Service.make(requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

          let(:unbind_response) { { binding: { route_service_url: route_service_url } } }
          let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }

          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
          end

          context 'async response not allowed' do
            let(:async_allowed) { false }

            it 'reports that a async is required' do
              result = action.delete(route_binding, async_allowed: async_allowed)
              expect(result).to be(described_class::RequiresAsync)
              expect(RouteBinding.first).to eq(route_binding)
            end
          end

          context 'async response allowed' do
            let(:async_allowed) { true }

            it_behaves_like 'successful delete'

            context 'service instance operation in progress' do
              before do
                service_instance.save_with_new_operation({}, {
                  type: 'create',
                  state: 'in progress',
                })
              end

              it 'fails with an appropriate error' do
                expect {
                  action.delete(route_binding, async_allowed: async_allowed)
                }.to raise_error(
                  described_class::UnprocessableDelete,
                  'There is an operation in progress for the service instance',
                )
              end
            end

            context 'broker returns an error' do
              let(:broker_client) do
                dbl = instance_double(VCAP::Services::ServiceBrokers::V2::Client)
                allow(dbl).to receive(:unbind).and_raise(StandardError, 'awful thing')
                dbl
              end

              it 'fails with an appropriate error' do
                expect {
                  action.delete(route_binding, async_allowed: async_allowed)
                }.to raise_error(
                  described_class::UnprocessableDelete,
                  "Service broker failed to delete service binding for instance #{service_instance.name}: awful thing",
                )
              end
            end
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }

          context 'async response not allowed' do
            let(:async_allowed) { false }

            it_behaves_like 'successful delete'
          end

          context 'async response allowed' do
            let(:async_allowed) { true }

            it_behaves_like 'successful delete'
          end
        end
      end
    end
  end
end
