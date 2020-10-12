require 'db_spec_helper'
require 'services/service_brokers/v2/errors/service_broker_bad_response'
require 'services/service_brokers/v2/errors/service_broker_request_rejected'
require 'cloud_controller/http_request_error'

RSpec.shared_examples 'service binding creation' do |binding_model|
  describe '#bind' do
    let(:service_offering) { VCAP::CloudController::Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
    end

    context 'sync binding' do
      let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

      it 'creates and returns the route binding' do
        action.bind(precursor)

        binding = precursor.reload
        expect(binding).to eq(binding_model.first)
        expect(binding.service_instance).to eq(service_instance)
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('succeeded')
      end

      context 'bind fails' do
        class BadError < StandardError; end

        let(:client) do
          dbl = double
          allow(dbl).to receive(:bind).and_raise(BadError)
          dbl
        end

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'marks the binding as failed' do
          expect {
            action.bind(precursor)
          }.to raise_error(BadError)

          binding = precursor.reload
          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('failed')
          expect(binding.last_operation.description).to eq('BadError')
        end
      end

      context 'parameters are specified' do
        it 'sends the parameters to the broker client' do
          action.bind(precursor, parameters: { foo: 'bar' })

          expect(broker_client).to have_received(:bind).with(
            precursor,
            arbitrary_parameters: { foo: 'bar' },
            accepts_incomplete: false,
          )
        end
      end
    end

    context 'asynchronous binding' do
      let(:broker_provided_operation) { Sham.guid }
      let(:bind_async_response) { { async: true, operation: broker_provided_operation } }
      let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_async_response) }

      it 'saves the operation ID and state in progress' do
        action.bind(precursor, accepts_incomplete: true)

        expect(broker_client).to have_received(:bind).with(
          precursor,
          arbitrary_parameters: {},
          accepts_incomplete: true,
        )

        binding = precursor.reload
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('in progress')
        expect(binding.last_operation.broker_provided_operation).to eq(broker_provided_operation)
      end

      context 'binding not retrievable' do
        let(:service_offering) { VCAP::CloudController::Service.make(bindings_retrievable: false, requires: ['route_forwarding']) }

        it 'it raises a BindingNotRetrievable error' do
          expect {
            action.bind(precursor, accepts_incomplete: true)
          }.to raise_error(VCAP::CloudController::V3::ServiceBindingCreate::BindingNotRetrievable)
        end
      end
    end
  end
end

RSpec.shared_examples 'polling service binding creation' do
  describe '#poll' do
    let(:service_offering) { VCAP::CloudController::Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
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
          fetch_service_binding: fetch_binding_response
        }
      )
    end

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
      allow(broker_client).to receive(:fetch_service_binding_last_operation).and_return(fetch_last_operation_response)

      action.bind(binding, accepts_incomplete: true)
    end

    it 'fetches the last operation' do
      action.poll(binding)

      expect(broker_client).to have_received(:fetch_service_binding_last_operation).with(binding)
    end

    context 'fetching last operations fails' do
      let(:response) {
        double('resp', body: '{"description":"no no no"}', code: 422, message: 'failed')
      }
      it 'should continue polling for known errors' do
        [
          VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new('uri', 'PUT', response),
          VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerRequestRejected.new('uri', 'PUT', response),
          HttpRequestError.new('no no no', 'uri', 'PUT', nil)
        ].each do |error|
          allow(broker_client).to receive(:fetch_service_binding_last_operation).and_raise(error)

          status = action.poll(binding)
          expect(status.finished).to be_falsey

          binding.reload
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.description).to include('no no no')
        end
      end

      it 'should stop polling for other errors' do
        allow(broker_client).to receive(:fetch_service_binding_last_operation).and_raise(RuntimeError)

        expect{ action.poll(binding) }.to raise_error(RuntimeError)

        binding.reload
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('failed')
        expect(binding.last_operation.description).to eq('RuntimeError')
      end
    end

    context 'response says complete' do
      let(:description) { Sham.description }
      let(:state) { 'succeeded' }

      it 'returns true' do
        polling_status = action.poll(binding)
        expect(polling_status[:finished]).to be_truthy
      end

      it 'updates the last operation' do
        action.poll(binding)

        binding.reload
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('succeeded')
        expect(binding.last_operation.description).to eq(description)
      end

      it 'fetches the service binding' do
        action.poll(binding)

        expect(broker_client).to have_received(:fetch_service_binding).with(binding)
      end

      context 'fails while fetching binding' do
        class BadError < StandardError; end

        before do
          allow(broker_client).to receive(:fetch_service_binding).and_raise(BadError)
        end

        it 'marks the binding as failed' do
          expect{ action.poll(binding) }.to raise_error(BadError)

          binding.reload
          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('failed')
          expect(binding.last_operation.description).to eq('BadError')
        end
      end
    end

    context 'response says in progress' do
      it 'returns false' do
        polling_status = action.poll(binding)
        expect(polling_status[:finished]).to be_falsey
      end

      it 'updates the last operation' do
        action.poll(binding)

        binding.reload
        expect(binding.last_operation.state).to eq('in progress')
        expect(binding.last_operation.description).to eq(description)
      end
    end

    context 'response says failed' do
      let(:state) { 'failed' }

      it 'returns true' do
        polling_status = action.poll(binding)
        expect(polling_status[:finished]).to be_truthy
      end

      it 'updates the last operation' do
        action.poll(binding)

        binding.reload
        expect(binding.last_operation.state).to eq('failed')
        expect(binding.last_operation.description).to eq(description)
      end
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
end
