require 'spec_helper'
require 'actions/v2/services/service_binding_read'

module VCAP::CloudController
  RSpec.describe ServiceBindingRead do
    let(:service) { Service.make(bindings_retrievable: true) }
    let(:fake_broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

    before do
      allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(fake_broker_client)
    end

    shared_examples_for 'a managed service instance binding' do
      context 'when the broker has bindings_retrievable enabled ' do
        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).with(instance: service_binding.service_instance).and_return(fake_broker_client)
        end

        it 'should use the client to fetch the service binding parameters' do
          expect(fake_broker_client).to receive(:fetch_service_binding).with(service_binding).and_return({})

          action = ServiceBindingRead.new
          action.fetch_parameters(service_binding)
        end

        it 'should return the "parameters" key from the broker response' do
          allow(fake_broker_client).to receive(:fetch_service_binding).with(service_binding).and_return({ parameters: { foo: 'bar' } })

          action = ServiceBindingRead.new
          expect(action.fetch_parameters(service_binding)).to eql({ foo: 'bar' })
        end

        it 'should return empty object when "parameters" key is missing' do
          allow(fake_broker_client).to receive(:fetch_service_binding).with(service_binding).and_return({ missing_parameters: { not: 'found' } })

          action = ServiceBindingRead.new
          expect(action.fetch_parameters(service_binding)).to eql({})
        end
      end

      context 'when the broker has bindings_retrievable disabled' do
        let(:service) { Service.make(bindings_retrievable: false) }

        it 'does not try to provide broker client' do
          expect(VCAP::Services::ServiceClientProvider).to_not receive(:provide)

          action = ServiceBindingRead.new
          begin
            action.fetch_parameters(service_binding)
          rescue ServiceBindingRead::NotSupportedError
            # tested elsewhere
          end
        end

        it 'should raise "NotSupportedError"' do
          action = ServiceBindingRead.new
          expect { action.fetch_parameters(service_binding) }.to raise_error(ServiceBindingRead::NotSupportedError)
        end
      end
    end

    describe '#fetch_parameters' do
      context 'managed service instance' do
        let(:service_plan) { ServicePlan.make(service: service) }
        let(:managed_service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        context 'an app binding' do
          let(:service_binding) { ServiceBinding.make(service_instance: managed_service_instance) }

          it_behaves_like 'a managed service instance binding'

          context 'when an operation is still in progress' do
            it 'should raise "ServiceBindingLockedError"' do
              service_binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress')
              service

              action = ServiceBindingRead.new
              expect { action.fetch_parameters(service_binding) }.to raise_error do |error|
                expect(error).to be_a(LockCheck::ServiceBindingLockedError)
                expect(error.service_binding).to eql(service_binding)
              end
            end
          end
        end

        context 'a key binding' do
          let(:service_binding) { ServiceKey.make(service_instance: managed_service_instance) }

          it_behaves_like 'a managed service instance binding'
        end
      end

      context 'user provided service instance' do
        let(:user_provided_service_instance) { UserProvidedServiceInstance.make }
        let(:service_binding) { ServiceBinding.make(service_instance: user_provided_service_instance) }

        it 'does not try to provide broker client' do
          expect(VCAP::Services::ServiceClientProvider).to_not receive(:provide)

          action = ServiceBindingRead.new
          begin
            action.fetch_parameters(service_binding)
          rescue ServiceBindingRead::NotSupportedError
            # tested elsewhere
          end
        end

        it 'should raise "NotSupportedError"' do
          action = ServiceBindingRead.new
          expect { action.fetch_parameters(service_binding) }.to raise_error(ServiceBindingRead::NotSupportedError)
        end
      end
    end
  end
end
