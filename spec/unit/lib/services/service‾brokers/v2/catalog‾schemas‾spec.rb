require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    let(:schemas) { CatalogSchemas.new(schema_data) }

    describe 'service_instance' do
      context 'when schemas service_instance is present and a hash' do
        let(:schema_data) do
          {
            'service_instance' => {
              'banana' => 'hello'
            }
          }
        end

        it 'should build the service instance schema' do
          expect(schemas.service_instance).to be_an_instance_of(ServiceInstanceSchema)
        end
      end

      context 'when schemas has no service_instance' do
        let(:schema_data) { {} }

        it 'should not build the service instance schema' do
          expect(schemas.service_instance).to be_nil
        end
      end

      context 'when schemas service_instance is not a hash' do
        let(:schema_data) do
          { 'service_instance' => 'not a hash'
          }
        end

        it 'should not build the service instance schema' do
          expect(schemas.service_instance).to be_nil
        end
      end
    end

    describe 'service_binding' do
      context 'when schemas service_binding is present and a hash' do
        let(:schema_data) do
          {
            'service_binding' => {
              'banana' => 'hello'
            }
          }
        end

        it 'should build the service binding schema' do
          expect(schemas.service_binding).to be_an_instance_of(ServiceBindingSchema)
        end
      end

      context 'when schemas has no service_binding' do
        let(:schema_data) { {} }

        it 'should not build the service binding schema' do
          expect(schemas.service_binding).to be_nil
        end
      end

      context 'when schemas service_binding is not a hash' do
        let(:schema_data) do
          {
            'service_binding' => 'not a hash'
          }
        end

        it 'should not build the service binding schema' do
          expect(schemas.service_binding).to be_nil
        end
      end
    end

    describe '#valid?' do
      context 'when service instance schema & service binding schema are not present' do
        let(:schema_data) { {} }

        it 'should be valid' do
          expect(schemas).to be_valid
        end
      end

      context 'when validating multiple times' do
        let(:schema_data) { { 'service_instance' => 'not a hash' } }

        before do
          schemas.valid?
          schemas.valid?
        end

        it 'should not duplicate errors' do
          expect(schemas.errors.messages.length).to eq 1
        end
      end

      context 'service instances' do
        context 'when the service instance data is not a hash' do
          let(:schema_data) { { 'service_instance' => 'not a hash' } }

          it 'should not be valid' do
            expect(schemas).to_not be_valid
            expect(schemas.errors.messages.length).to eq 1
            expect(schemas.errors.messages.first).to match 'Schemas service_instance must be a hash, but has value \"not a hash\"'
          end
        end

        context 'when the service instance schema is not valid' do
          let(:service_instance_schema) do
            instance_double(ServiceInstanceSchema, valid?: false, errors: 'whoops')
          end
          let(:schema_data) do
            {
              'service_instance' => {
                'something' => 'something else'
              }
            }
          end

          before { allow(ServiceInstanceSchema).to receive(:new).and_return(service_instance_schema) }

          it 'is invalid and adds a nested error' do
            expect(schemas).to_not be_valid
            expect(schemas.errors.nested_errors[service_instance_schema]).to eq('whoops')
          end
        end
      end

      context 'service bindings' do
        context 'when the service binding data is not a hash' do
          let(:schema_data) { { 'service_binding' => 'not a hash' } }

          it 'should not be valid' do
            expect(schemas).to_not be_valid
            expect(schemas.errors.messages.length).to eq 1
            expect(schemas.errors.messages.first).to match 'Schemas service_binding must be a hash, but has value \"not a hash\"'
          end
        end

        context 'when the service binding schema is not valid' do
          let(:service_binding_schema) do
            instance_double(ServiceBindingSchema, valid?: false, errors: 'whoops')
          end
          let(:schema_data) do
            {
              'service_binding' => {
                'something' => 'something else'
              }
            }
          end

          before { allow(ServiceBindingSchema).to receive(:new).and_return(service_binding_schema) }

          it 'is invalid and adds a nested error' do
            expect(schemas).to_not be_valid
            expect(schemas.errors.nested_errors[service_binding_schema]).to eq('whoops')
          end
        end
      end
    end
  end
end
