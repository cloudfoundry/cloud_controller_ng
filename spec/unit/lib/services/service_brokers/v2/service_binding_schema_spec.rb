require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe 'schema validation' do
    describe 'ServiceBindingSchema' do
      subject do
        service_binding_schema = ServiceBindingSchema.new(binding)
        service_binding_schema.valid?
        service_binding_schema
      end

      context 'create' do
        context 'when not set' do
          let(:binding) { {} }

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:create) { is_expected.to be_nil }
        end

        context 'when set to an empty hash' do
          let(:binding) { { 'create' => {} } }

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:create) { is_expected.not_to be_nil }
        end

        context 'when it is not hash' do
          let(:binding) { { 'create' => true } }

          its(:valid?) { is_expected.to be false }
          its('errors.messages') { is_expected.to have(1).items }
          its('errors.messages.first') { is_expected.to eq 'Schemas service_binding.create must be a hash, but has value true' }
          its(:create) { is_expected.to be_nil }
        end

        context 'when it not valid' do
          let(:binding) { { 'create' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }

          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { is_expected.to be false }
          its('errors.nested_errors') { is_expected.to have(1).items }
        end
      end
    end
  end
end
