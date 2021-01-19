require 'spec_helper'
require 'actions/service_credential_binding_delete'
require 'support/shared_examples/v3_service_binding_delete'

module VCAP::CloudController
  module V3
    RSpec.describe V3::ServiceCredentialBindingDelete do
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: user_guid) }
      let(:action) { described_class.new(type, user_audit_info) }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }
      let(:space) { Space.make }

      before do
        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with(audit_event).and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_delete)
        allow(binding_event_repo).to receive(:record_start_delete)
      end

      RSpec.shared_examples 'successful credential binding delete' do |klass|
        it 'deletes the binding' do
          action.delete(binding)

          expect(klass.all).to be_empty
        end

        it 'creates an audit event' do
          action.delete(binding)

          expect(binding_event_repo).to have_received(:record_delete).with(
            binding,
            user_audit_info,
          )
        end

        it 'says the the delete is complete' do
          result = action.delete(binding)

          expect(result[:finished]).to be_truthy
        end
      end

      RSpec.shared_examples 'managed service instance binding delete' do |klass|
        context 'managed service instance' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          it_behaves_like 'service binding deletion', klass

          context 'broker returns delete complete' do
            let(:unbind_response) { { async: false } }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'successful credential binding delete', klass
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
      end

      RSpec.shared_examples 'polling last operation' do |klass|
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

          context 'last operation state is complete' do
            let(:state) { 'succeeded' }

            it 'logs an audit event' do
              result = action.poll(binding)

              expect(klass.all).to be_empty
              expect(binding_event_repo).to have_received(:record_delete).with(
                binding,
                user_audit_info,
              )
              expect(result[:finished]).to be_truthy
            end
          end

          context 'last operation state is in progress' do
            let(:state) { 'in progress' }

            it 'does not log an audit event' do
              action.poll(binding)

              expect(klass.first).to eq(binding)
              expect(binding_event_repo).not_to have_received(:record_delete)
            end
          end

          context 'last operation state is failed' do
            let(:state) { 'failed' }

            it 'does not create an audit event' do
              expect { action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

              expect(klass.first).to eq(binding)
              expect(binding_event_repo).not_to have_received(:record_delete)
            end
          end

          context 'broker client raises' do
            it 'does not create an audit event' do
              allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_raise(StandardError, 'awful thing')

              expect { action.poll(binding) }.to raise_error(StandardError)

              expect(klass.first).to eq(binding)
              expect(binding_event_repo).not_to have_received(:record_delete)
            end
          end
        end
      end

      RSpec.shared_examples 'blocking operation in progress' do
        describe 'delete in progress' do
          let(:last_operation_type) { 'delete' }
          let(:last_operation_state) { 'in progress' }

          it 'is blocking' do
            expect(action.blocking_operation_in_progress?(binding)).to be_truthy
          end
        end

        describe 'create in progress' do
          let(:last_operation_type) { 'create' }
          let(:last_operation_state) { 'in progress' }

          it 'is not blocking' do
            expect(action.blocking_operation_in_progress?(binding)).to be_falsey
          end
        end

        describe 'operation not in progress' do
          let(:last_operation_type) { 'delete' }
          let(:last_operation_state) { 'failed' }

          it 'is not blocking' do
            expect(action.blocking_operation_in_progress?(binding)).to be_falsey
          end
        end
      end

      describe 'app binding' do
        let(:audit_event) { 'service_binding' }
        let(:type) { :credential }
        let(:app) { AppModel.make(space: space) }
        let(:last_operation_type) { 'create' }
        let(:last_operation_state) { 'successful' }
        let(:binding) do
          VCAP::CloudController::ServiceBinding.new.save_with_attributes_and_new_operation(
            { type: 'app', service_instance: service_instance, app: app, credentials: { test: 'secretPassword' } },
            { type: last_operation_type, state: last_operation_state }
          )
        end

        describe '#blocking_operation_in_progress?' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          it_behaves_like 'blocking operation in progress'
        end

        describe '#delete' do
          it_behaves_like 'managed service instance binding delete', ServiceBinding

          context 'user-provided service instance' do
            let(:service_instance) { UserProvidedServiceInstance.make(space: space) }

            it_behaves_like 'successful credential binding delete', ServiceBinding
          end
        end

        describe '#poll' do
          it_behaves_like 'polling last operation', ServiceBinding
        end
      end

      describe 'key binding' do
        let(:type) { :key }
        let(:audit_event) { 'service_key' }
        let(:last_operation_type) { 'create' }
        let(:last_operation_state) { 'successful' }
        let(:binding) do
          VCAP::CloudController::ServiceKey.new.save_with_attributes_and_new_operation(
            { name: 'binding_name', service_instance: service_instance, credentials: { test: 'secretPassword' } },
            { type: last_operation_type, state: last_operation_state }
          )
        end

        describe '#blocking_operation_in_progress?' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          it_behaves_like 'blocking operation in progress'
        end

        describe '#delete' do
          it_behaves_like 'managed service instance binding delete', ServiceKey
        end

        describe '#poll' do
          it_behaves_like 'polling last operation', ServiceKey
        end
      end
    end
  end
end
