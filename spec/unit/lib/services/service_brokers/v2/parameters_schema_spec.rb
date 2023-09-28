require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe ParametersSchema do
    let(:parameters_schema) { ParametersSchema.new(parameters, ['path']) }

    describe 'validations' do
      context 'schema' do
        let(:parameters) { { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#' } } }

        it 'is valid' do
          expect(parameters_schema).to be_valid
          expect(parameters_schema.errors).to be_empty
          expect(parameters_schema.parameters).to be_an_instance_of(Schema)
        end

        context 'when parameters is empty' do
          let(:parameters) { {} }

          it 'is valid' do
            expect(parameters_schema).to be_valid
            expect(parameters_schema.errors).to be_empty
            expect(parameters_schema.parameters).to be_nil
          end
        end

        context 'when parameters is not hash' do
          let(:parameters) { { 'parameters' => true } }

          it 'is not valid' do
            expect(parameters_schema).not_to be_valid
            expect(parameters_schema.errors.messages.length).to eq 1
            expect(parameters_schema.errors.messages.first).to eq 'Schemas path.parameters must be a hash, but has value true'
            expect(parameters_schema.parameters).to be_nil
          end
        end
      end
    end
  end
end
