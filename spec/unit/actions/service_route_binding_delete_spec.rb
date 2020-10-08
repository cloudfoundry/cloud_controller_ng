require 'spec_helper'
require 'actions/service_route_binding_delete'

module VCAP::CloudController
  module V3
    RSpec.shared_examples 'successful delete' do
      it 'deletes the binding' do
        perform_action

        expect(RouteBinding.all).to be_empty
      end

      it 'creates an audit event' do
        perform_action

        expect(event_repository).to have_received(:record_service_instance_event).with(
          :unbind_route,
          service_instance,
          { route_guid: route.guid },
        )
      end

      it 'says the the delete is complete' do
        expect(perform_action).to be_a(described_class::DeleteComplete)
      end

      context 'route does not have app' do
        it 'does not notify diego' do
          perform_action

          expect(messenger).not_to have_received(:send_desire_request)
        end
      end

      context 'route has app' do
        let(:process) { ProcessModelFactory.make(space: route.space, state: 'STARTED') }

        it 'notifies diego' do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)

          perform_action

          expect(messenger).to have_received(:send_desire_request).with(process)
        end
      end
    end

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
      let(:action) { described_class.new(event_repository) }

      before do
        allow(Diego::Messenger).to receive(:new).and_return(messenger)
      end

      describe '#delete' do
        subject(:delete_binding) { action.delete(route_binding, async_allowed: async_allowed) }

        context 'managed service instance' do
          let(:service_offering) { Service.make(requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

          let(:unbind_response) { { async: false } }
          let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }

          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
          end

          context 'async response not allowed' do
            let(:async_allowed) { false }

            it 'reports that a async is required' do
              expect(delete_binding).to be_a(described_class::RequiresAsync)
              expect(RouteBinding.first).to eq(route_binding)
            end
          end

          context 'async response allowed' do
            let(:async_allowed) { true }

            it 'makes the right call to the broker client' do
              delete_binding

              expect(broker_client).to have_received(:unbind).with(route_binding, nil, true)
            end

            context 'broker returns delete complete' do
              let(:perform_action) { delete_binding }

              it_behaves_like 'successful delete'
            end

            context 'broker returns delete in progress' do
              let(:operation) { Sham.guid }
              let(:unbind_response) { { async: true, operation: operation } }

              it 'says the the delete is in progress' do
                expect(delete_binding).to eq(described_class::DeleteStarted.new(operation))
              end

              it 'updates the last operation' do
                delete_binding

                expect(route_binding.last_operation.type).to eq('delete')
                expect(route_binding.last_operation.state).to eq('in progress')
                expect(route_binding.last_operation.broker_provided_operation).to eq(operation)
                expect(route_binding.last_operation.description).to be_nil
              end

              it 'does not remove the binding or log an audit event' do
                delete_binding

                expect(RouteBinding.first).to eq(route_binding)
                expect(event_repository).not_to have_received(:record_service_instance_event)
              end
            end

            context 'service instance operation in progress' do
              before do
                service_instance.save_with_new_operation({}, {
                  type: 'create',
                  state: 'in progress',
                })
              end

              it 'fails with an appropriate error' do
                expect {
                  delete_binding
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

              it 'fails with an appropriate error and stores the message in the binding' do
                expect {
                  delete_binding
                }.to raise_error(
                  described_class::UnprocessableDelete,
                  "Service broker failed to delete service binding for instance #{service_instance.name}: awful thing",
                )

                expect(route_binding.last_operation.type).to eq('delete')
                expect(route_binding.last_operation.state).to eq('failed')
                expect(route_binding.last_operation.description).to eq("Service broker failed to delete service binding for instance #{service_instance.name}: awful thing")
              end
            end
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }
          let(:perform_action) { delete_binding }

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

      describe '#poll' do
        let(:service_offering) { Service.make(requires: ['route_forwarding']) }
        let(:service_plan) { ServicePlan.make(service: service_offering) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

        let(:description) { Sham.description }
        let(:last_operation_response) do
          {
            last_operation: {
              state: state,
              description: description,
            },
          }
        end
        let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, fetch_service_binding_last_operation: last_operation_response) }

        before do
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
        end

        subject(:poll_binding) { action.poll(route_binding) }

        context 'broker client says in progress' do
          let(:state) { 'in progress' }

          it 'returns delete in progress' do
            expect(poll_binding).to be_a(described_class::DeleteInProgress)
          end

          it 'updates the last operation' do
            poll_binding
            route_binding.reload

            expect(route_binding.last_operation.type).to eq('delete')
            expect(route_binding.last_operation.state).to eq('in progress')
            expect(route_binding.last_operation.description).to eq(description)
          end

          it 'does not remove the binding or log an audit event' do
            poll_binding

            expect(RouteBinding.first).to eq(route_binding)
            expect(event_repository).not_to have_received(:record_service_instance_event)
          end

          context 'retry interval' do
            context 'no retry interval' do
              it 'returns nil' do
                expect(poll_binding.retry_after).to be_nil
              end
            end

            context 'retry interval specified' do
              let(:last_operation_response) do
                {
                  last_operation: {
                    state: state,
                    description: description,
                  },
                  retry_after: 10,
                }
              end

              it 'returns the value' do
                expect(poll_binding.retry_after).to eq(10)
              end
            end
          end
        end

        context 'broker client says finished' do
          let(:state) { 'succeeded' }
          let(:perform_action) { poll_binding }

          it_behaves_like 'successful delete'
        end

        context 'broker client says failed' do
          let(:state) { 'failed' }

          it 'returns complete' do
            expect(poll_binding).to be_a(described_class::DeleteComplete)
          end

          it 'updates the last operation' do
            poll_binding

            route_binding.reload
            expect(route_binding.last_operation.state).to eq('failed')
            expect(route_binding.last_operation.description).to eq(description)
          end

          it 'does not notify diego or create an audit event' do
            poll_binding

            expect(messenger).not_to have_received(:send_desire_request)
            expect(event_repository).not_to have_received(:record_service_instance_event)
          end
        end

        context 'broker client raises' do
          let(:broker_client) do
            dbl = instance_double(VCAP::Services::ServiceBrokers::V2::Client)
            allow(dbl).to receive(:fetch_service_binding_last_operation).and_raise(StandardError, 'awful thing')
            dbl
          end

          it 'saves the error in the last operation' do
            poll_binding

            route_binding.reload
            expect(route_binding.last_operation.state).to eq('in progress')
            expect(route_binding.last_operation.description).to eq('awful thing')

            expect(messenger).not_to have_received(:send_desire_request)
            expect(event_repository).not_to have_received(:record_service_instance_event)
          end
        end
      end
    end
  end
end
