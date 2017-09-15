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
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:create) { should be nil }
        end

        context 'when set to an empty hash' do
          let(:binding) { { 'create' => {} } }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:create) { should_not be nil }
        end

        context 'when it is not hash ' do
          let(:binding) { { 'create' => true } }

          its(:valid?) { should be false }
          its('errors.messages') { should have(1).items }
          its('errors.messages.first') { should eq 'Schemas service_binding.create must be a hash, but has value true' }
          its(:create) { should be nil }
        end

        context 'when it not valid' do
          let(:binding) { { 'create' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }
          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { should be false }
          its('errors.nested_errors') { should have(1).items }
        end
      end
    end
  end
end
