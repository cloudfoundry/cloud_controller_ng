require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe 'schema validation' do
    describe 'ParametersSchema' do
      subject do
        parameters_schema = ParametersSchema.new(parameters, ['path'])
        parameters_schema.valid?
        parameters_schema
      end

      context 'schema' do
        context 'when not set' do
          let(:parameters) { {} }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:schema) { should be nil }
        end

        context 'when it is not hash ' do
          let(:parameters) { { 'parameters' => true } }

          its(:valid?) { should be false }
          its('errors.messages') { should have(1).items }
          its('errors.messages.first') { should eq 'Schemas path.parameters must be a hash, but has value true' }
          its(:schema) { should be nil }
        end

        context 'when it not valid' do
          let(:parameters) { { 'parameters' => {} } }
          before do
            validation_error = double('error')
            allow(validation_error).to receive(:messages).and_return({ 'error' => ['some error'] })
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Schema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Schema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { should be false }
          its('errors.messages') { should have(1).items }
        end
      end
    end
  end
end
