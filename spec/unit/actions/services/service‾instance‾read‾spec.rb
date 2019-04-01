require 'spec_helper'
require 'actions/services/service_instance_read'

module VCAP::CloudController
  RSpec.describe ServiceInstanceRead do
    let(:service) { Service.make }
    let(:service_plan) { ServicePlan.make(service: service) }
    let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

    describe '#fetch_parameters' do
      context 'when the service supports fetching instance parameters' do
        let(:service) { Service.make(instances_retrievable: true) }
        let(:fake_broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).with(instance: service_instance).and_return(fake_broker_client)
        end

        it 'calls the broker to fetch parameters' do
          expect(fake_broker_client).to receive(:fetch_service_instance).with(service_instance).and_return({})

          action = ServiceInstanceRead.new
          action.fetch_parameters(service_instance)
        end

        context 'and the broker returns a parameters key' do
          it 'returns the parameters fetched from the broker' do
            broker_response = { parameters: { foo: 'bar' } }
            allow(fake_broker_client).to receive(:fetch_service_instance).with(service_instance).and_return(broker_response)

            action = ServiceInstanceRead.new
            expect(action.fetch_parameters(service_instance)).to eql({ foo: 'bar' })
          end
        end

        context 'and the broker returns another key' do
          it 'returns an empty object' do
            broker_response = { something: { foo: 'bar' } }
            allow(fake_broker_client).to receive(:fetch_service_instance).with(service_instance).and_return(broker_response)

            action = ServiceInstanceRead.new
            expect(action.fetch_parameters(service_instance)).to eql({})
          end
        end

        context 'and the broker returns an empty object' do
          it 'returns an empty object' do
            broker_response = {}
            allow(fake_broker_client).to receive(:fetch_service_instance).with(service_instance).and_return(broker_response)

            action = ServiceInstanceRead.new
            expect(action.fetch_parameters(service_instance)).to eql({})
          end
        end

        context 'and the broker client raises an exception' do
          it 're-throws the error' do
            allow(fake_broker_client).to receive(:fetch_service_instance).and_raise(StandardError.new)

            action = ServiceInstanceRead.new
            expect { action.fetch_parameters(service_instance) }.to raise_error(StandardError)
          end
        end

        context 'when the service instance has an operation in progress' do
          let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }

          before do
            service_instance.service_instance_operation = last_operation
            service_instance.save
          end

          it 'should raise an async operation in progress error' do
            action = ServiceInstanceRead.new

            expect { action.fetch_parameters(service_instance) }.to raise_error do |error|
              expect(error).to be_a(CloudController::Errors::ApiError)
              expect(error.name).to eql('AsyncServiceInstanceOperationInProgress')
            end
          end
        end
      end

      context 'when the service does not support fetching instance parameters' do
        context 'when the service instance is user provided' do
          let(:service_instance) { UserProvidedServiceInstance.make }

          it 'does not call the broker to fetch parameters' do
            expect(VCAP::Services::ServiceClientProvider).to_not receive(:provide)

            action = ServiceInstanceRead.new
            begin
              action.fetch_parameters(service_instance)
            rescue
              # tested elsewhere
            end
          end

          it 'raises an exception' do
            action = ServiceInstanceRead.new
            expect { action.fetch_parameters(service_instance) }.to raise_error(ServiceInstanceRead::NotSupportedError)
          end
        end

        context 'when the service has instances_retrievable set to false' do
          let(:service) { Service.make(instances_retrievable: false) }

          it 'does not call the broker to fetch parameters' do
            expect(VCAP::Services::ServiceClientProvider).to_not receive(:provide)

            action = ServiceInstanceRead.new
            begin
              action.fetch_parameters(service_instance)
            rescue
              # tested elsewhere
            end
          end

          it 'raises an exception' do
            action = ServiceInstanceRead.new
            expect { action.fetch_parameters(service_instance) }.to raise_error(ServiceInstanceRead::NotSupportedError)
          end

          context 'and has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }

            before do
              service_instance.service_instance_operation = last_operation
              service_instance.save
            end

            it 'should raise a NotSupporedError instead of ' do
              action = ServiceInstanceRead.new
              expect { action.fetch_parameters(service_instance) }.to raise_error(ServiceInstanceRead::NotSupportedError)
            end
          end
        end
      end
    end
  end
end
