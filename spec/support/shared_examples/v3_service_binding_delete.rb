require 'db_spec_helper'
require 'services/service_brokers/v2/errors/service_broker_bad_response'
require 'services/service_brokers/v2/errors/service_broker_request_rejected'
require 'cloud_controller/http_request_error'

RSpec.shared_examples 'service binding deletion' do |binding_model|
  describe '#delete' do
    let(:service_offering) { VCAP::CloudController::Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    let(:unbind_response) { { async: false } }
    let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: unbind_response) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
    end

    it 'makes the right call to the broker client' do
      action.delete(binding)

      expect(broker_client).to have_received(:unbind).with(
        binding,
        accepts_incomplete: true,
        user_guid: user_guid
      )
    end

    context 'unbind fails with generic error' do
      class BadError < StandardError; end

      let(:broker_client) do
        dbl = instance_double(VCAP::Services::ServiceBrokers::V2::Client)
        allow(dbl).to receive(:unbind).and_raise(StandardError, 'awful thing')
        dbl
      end

      it 'fails with an appropriate error and stores the message in the binding' do
        expect {
          action.delete(binding)
        }.to raise_error(
          described_class::UnprocessableDelete,
          "Service broker failed to delete service binding for instance #{service_instance.name}: awful thing",
        )

        binding.reload
        expect(binding.last_operation.type).to eq('delete')
        expect(binding.last_operation.state).to eq('failed')
        expect(binding.last_operation.description).to eq("Service broker failed to delete service binding for instance #{service_instance.name}: awful thing")
      end
    end

    context 'when a create operation is already in progress' do
      before do
        binding.save_with_attributes_and_new_operation(
          {},
          { type: 'create', state: 'in progress', description: 'doing stuff' }
        )
      end

      context 'broker accepts delete request' do
        it 'removes the binding' do
          action.delete(binding)

          expect(binding_model.all).to be_empty
        end
      end

      context 'broker rejects delete request' do
        let(:broker_client) do
          dbl = instance_double(VCAP::Services::ServiceBrokers::V2::Client)
          allow(dbl).to receive(:unbind).and_raise(
            VCAP::Services::ServiceBrokers::V2::Errors::ConcurrencyError.new(
              'foo',
              :delete,
              double(code: '500', reason: '', body: '')
            )
          )
          dbl
        end

        it 'fails with an appropriate error and does not alter the binding' do
          expect {
            action.delete(binding)
          }.to raise_error(
            described_class::ConcurrencyError,
            'The service broker rejected the request due to an operation being in progress for the service binding.',
          )

          binding.reload
          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.description).to eq('doing stuff')
        end
      end
    end

    context 'when a delete operation is already in progress' do
      before do
        binding.save_with_attributes_and_new_operation(
          {},
          { type: 'delete', state: 'in progress', description: 'doing stuff' }
        )
      end

      it 'fails with an appropriate error and does not alter the binding' do
        expect {
          action.delete(binding)
        }.to raise_error(
          described_class::ConcurrencyError,
          'The delete request was rejected due to an operation being in progress for the service binding.',
        )

        binding.reload
        expect(binding.last_operation.type).to eq('delete')
        expect(binding.last_operation.state).to eq('in progress')
        expect(binding.last_operation.description).to eq('doing stuff')
      end
    end

    context 'sync unbinding' do
      it 'removes the binding' do
        action.delete(binding)

        expect(binding_model.all).to be_empty
      end
    end

    context 'asynchronous unbinding' do
      context 'broker returns delete in progress' do
        let(:operation) { Sham.guid }
        let(:unbind_response) { { async: true, operation: operation } }

        it 'says the the delete is in progress' do
          result = action.delete(binding)

          expect(result[:finished]).to be_falsey
          expect(result[:operation]).to eq(operation)
        end

        it 'updates the last operation' do
          action.delete(binding)

          expect(binding.last_operation.type).to eq('delete')
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.broker_provided_operation).to eq(operation)
          expect(binding.last_operation.description).to be_nil
        end

        it 'does not remove the binding' do
          action.delete(binding)

          expect(binding_model.first).to eq(binding)
        end
      end
    end
  end
end

RSpec.shared_examples 'polling service binding deletion' do
  describe '#poll' do
    let(:service_offering) { VCAP::CloudController::Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
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

    let(:broker_provided_operation) { Sham.guid }
    let(:unbind_response) { { async: true, operation: broker_provided_operation } }
    let(:broker_client) do
      instance_double(
        VCAP::Services::ServiceBrokers::V2::Client,
        {
          unbind: unbind_response,
        }
      )
    end

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
      allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_return(fetch_last_operation_response)

      action.delete(binding)
    end

    it 'fetches the last operation' do
      action.poll(binding)

      expect(broker_client).to have_received(:fetch_and_handle_service_binding_last_operation).with(binding, user_guid: user_guid)
    end

    context 'last operation state is complete' do
      let(:description) { Sham.description }
      let(:state) { 'succeeded' }

      it 'returns true' do
        polling_status = action.poll(binding)
        expect(polling_status[:finished]).to be_truthy
      end
    end

    context 'last operation state is in progress' do
      let(:state) { 'in progress' }

      it 'returns false' do
        polling_status = action.poll(binding)
        expect(polling_status[:finished]).to be_falsey
      end

      it 'updates the last operation' do
        action.poll(binding)

        binding.reload
        expect(binding.last_operation.state).to eq('in progress')
        expect(binding.last_operation.description).to eq(description)
        expect(binding.last_operation.broker_provided_operation).to eq(broker_provided_operation)
      end

      context 'retry interval' do
        context 'no retry interval' do
          it 'returns nil' do
            polling_status = action.poll(binding)
            expect(polling_status[:retry_after]).to be_nil
          end
        end

        context 'retry interval specified' do
          let(:fetch_last_operation_response) do
            {
              last_operation: {
                state: state,
                description: description,
              },
              retry_after: 10,
            }
          end

          it 'returns the value when there was a retry header' do
            polling_status = action.poll(binding)
            expect(polling_status.finished).to be_falsey
            expect(polling_status.retry_after).to eq(10)
          end
        end
      end
    end

    context 'last operation state is failed' do
      let(:state) { 'failed' }

      it 'updates the last operation' do
        expect { action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

        binding.reload
        expect(binding.last_operation.state).to eq('failed')
        expect(binding.last_operation.description).to eq(description)
      end
    end

    context 'fetching last operations fails' do
      before do
        allow(broker_client).to receive(:fetch_and_handle_service_binding_last_operation).and_raise(RuntimeError.new('some error'))
      end

      it 'should stop polling for other errors' do
        expect { action.poll(binding) }.to raise_error(RuntimeError)

        binding.reload
        expect(binding.last_operation.type).to eq('delete')
        expect(binding.last_operation.state).to eq('failed')
        expect(binding.last_operation.description).to eq('some error')
      end
    end
  end
end
