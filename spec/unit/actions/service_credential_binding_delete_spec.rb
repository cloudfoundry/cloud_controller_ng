require 'spec_helper'
require 'actions/service_credential_binding_delete'
require 'support/shared_examples/v3_service_binding_delete'

module VCAP::CloudController
  module V3
    RSpec.shared_examples 'successful credential binding delete' do
      it 'deletes the binding' do
        action.delete(binding)

        expect(ServiceBinding.all).to be_empty
      end

      it 'says the the delete is complete' do
        result = action.delete(binding)

        expect(result[:finished]).to be_truthy
      end
    end

    RSpec.describe V3::ServiceCredentialBindingDelete do
      let(:action) { described_class.new }

      let(:space) { Space.make }
      let(:app) { AppModel.make(space: space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.new.save_with_attributes_and_new_operation(
          { type: 'app', service_instance: service_instance, app: app, credentials: { test: 'secretPassword' } },
          { type: 'create', state: 'successful' }
        )
      end

      describe '#delete' do
        context 'managed service instance' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          it_behaves_like 'service binding deletion', ServiceBinding

          context 'broker returns delete complete' do
            let(:unbind_response) { { async: false } }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'successful credential binding delete'
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space) }

          it_behaves_like 'successful credential binding delete'
        end
      end

      describe '#poll' do
        let(:service_instance) { ManagedServiceInstance.make(space: space) }
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

        it_behaves_like 'polling service binding deletion'

        context 'last operation state is in progress' do
          let(:state) { 'in progress' }

          it 'does not log an audit event' do
            action.poll(binding)

            expect(ServiceBinding.first).to eq(binding)
            # expect(event_repository).not_to have_received(:record_service_instance_event)
          end
        end

        context 'last operation state is failed' do
          let(:state) { 'failed' }

          it 'does not create an audit event' do
            expect { action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

            expect(ServiceBinding.first).to eq(binding)
            # expect(event_repository).not_to have_received(:record_service_instance_event)
          end
        end

        context 'broker client raises' do
          it 'does not create an audit event' do
            allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_raise(StandardError, 'awful thing')

            expect { action.poll(binding) }.to raise_error(StandardError)

            expect(ServiceBinding.first).to eq(binding)
            # expect(event_repository).not_to have_received(:record_service_instance_event)
          end
        end
      end
    end
  end
end
