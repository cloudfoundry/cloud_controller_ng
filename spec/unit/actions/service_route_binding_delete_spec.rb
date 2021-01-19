require 'spec_helper'
require 'actions/service_route_binding_delete'
require 'support/shared_examples/v3_service_binding_delete'
require 'unit/actions/service_credential_binding_delete_spec'

module VCAP::CloudController
  module V3
    RSpec.shared_examples 'successful route binding delete' do
      it 'deletes the binding' do
        perform_action

        expect(RouteBinding.all).to be_empty
      end

      it 'creates an audit event' do
        perform_action

        expect(binding_event_repo).to have_received(:record_delete).with(
          binding,
          user_audit_info,
        )
      end

      it 'says the the delete is complete' do
        expect(perform_action[:finished]).to be_truthy
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
      let(:last_operation_type) { 'create' }
      let(:last_operation_state) { 'successful' }
      let(:binding) do
        VCAP::CloudController::RouteBinding.new.save_with_new_operation(
          { service_instance: service_instance, route: route, route_service_url: route_service_url },
          { type: last_operation_type, state: last_operation_state }
        )
      end
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: user_guid) }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }

      let(:messenger) { instance_double(Diego::Messenger, send_desire_request: nil) }
      let(:action) { described_class.new(user_audit_info) }

      before do
        allow(Diego::Messenger).to receive(:new).and_return(messenger)

        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with('service_route_binding').and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_delete)
        allow(binding_event_repo).to receive(:record_start_delete)
      end

      describe '#blocking_operation_in_progress?' do
        let(:service_offering) { Service.make(requires: ['route_forwarding']) }
        let(:service_plan) { ServicePlan.make(service: service_offering) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

        it_behaves_like 'blocking operation in progress'
      end

      describe '#delete' do
        context 'managed service instance' do
          let(:service_offering) { Service.make(requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

          it_behaves_like 'service binding deletion', RouteBinding

          context 'broker returns delete complete' do
            let(:unbind_response) { { async: false } }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }
            let(:perform_action) { action.delete(binding) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'successful route binding delete'
          end

          context 'async unbinding' do
            let(:broker_provided_operation) { Sham.guid }
            let(:async_unbind_response) { { async: true, operation: broker_provided_operation } }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: async_unbind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it 'should log audit start_create' do
              action.delete(binding)

              expect(binding_event_repo).to have_received(:record_start_delete).with(
                binding,
                user_audit_info,
              )
            end
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }
          let(:perform_action) { action.delete(binding) }

          it_behaves_like 'successful route binding delete'
        end
      end

      describe '#poll' do
        let(:service_offering) { Service.make(requires: ['route_forwarding']) }
        let(:service_plan) { ServicePlan.make(service: service_offering) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

        let(:description) { Sham.description }
        let(:state) { 'in progress' }
        let(:last_operation_response) do
          {
            last_operation: {
              state: state,
              description: description,
            },
          }
        end
        let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
        let(:broker_provided_operation) { Sham.guid }

        before do
          binding.last_operation.broker_provided_operation = broker_provided_operation
          binding.save

          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
          allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_return(last_operation_response)
        end

        subject(:poll_binding) { action.poll(binding) }

        it_behaves_like 'polling service binding deletion'

        context 'last operation state is complete' do
          let(:description) { Sham.description }
          let(:state) { 'succeeded' }
          let(:perform_action) { poll_binding }

          it_behaves_like 'successful route binding delete'
        end

        context 'last operation state is in progress' do
          let(:state) { 'in progress' }

          it 'does not remove the binding or log an audit event' do
            poll_binding

            expect(RouteBinding.first).to eq(binding)
            expect(messenger).not_to have_received(:send_desire_request)
            expect(binding_event_repo).not_to have_received(:record_delete)
          end
        end

        context 'last operation state is failed' do
          let(:state) { 'failed' }

          it 'does not notify diego or create an audit event' do
            expect { action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

            expect(RouteBinding.first).to eq(binding)
            expect(messenger).not_to have_received(:send_desire_request)
            expect(binding_event_repo).not_to have_received(:record_delete)
          end
        end

        context 'broker client raises' do
          it 'does not notify diego or create an audit event' do
            allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_raise(StandardError, 'awful thing')

            expect { action.poll(binding) }.to raise_error(StandardError)

            expect(RouteBinding.first).to eq(binding)
            expect(messenger).not_to have_received(:send_desire_request)
            expect(binding_event_repo).not_to have_received(:record_delete)
          end
        end
      end
    end
  end
end
