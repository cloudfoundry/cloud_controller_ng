require 'spec_helper'
require 'actions/service_credential_binding_key_create'
require 'support/shared_examples/v3_service_binding_create'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingKeyCreate do
      subject(:action) { described_class.new() }

      let(:space) { Space.make }
      let(:binding_details) {}
      let(:name) { 'test-key'}

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, name)

            expect(binding).to be
            expect(binding).to eq(ServiceKey.where(guid: binding.guid).first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.name).to eq(name)
            expect(binding.credentials).to be_empty
          end

          it 'raises an error when a key with same name already exists' do
            binding = ServiceKey.make(service_instance: service_instance)
            expect { action.precursor(service_instance, binding.name) }.to raise_error(
              ServiceCredentialBindingKeyCreate::UnprocessableCreate,
              "The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{binding.name}'."
            )
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make() }

          it 'raises error' do
            expect { action.precursor(service_instance, name) }.to raise_error(
              ServiceCredentialBindingKeyCreate::UnprocessableCreate,
              "Service credential bindings of type 'key' are not supported for user-provided service instances."
            )
          end
        end

        context 'managed service instance' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          context 'when plan is not bindable' do
            before do
              service_instance.service_plan.update(bindable: false)
            end

            it 'raises an error' do
              expect { action.precursor(service_instance, name) }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                'Service plan does not allow bindings.'
              )
            end
          end

          context 'when plan is not available' do
            before do
              service_instance.service_plan.update(active: false)
            end

            it 'raises an error' do
              expect { action.precursor(service_instance, name) }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                'Service plan is not available.'
              )
            end
          end

          context 'when there is an operation in progress for the service instance' do
            it 'raises an error' do
              service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

              expect {
                action.precursor(service_instance, name)
              }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                'There is an operation in progress for the service instance.'
              )
            end
          end

          context 'when successful' do
            it_behaves_like 'the credential binding precursor'
          end
        end
      end
    end
  end
end
