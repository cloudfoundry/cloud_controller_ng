require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'validating catalog schemas' do
      let(:catalog_schemas) { CatalogSchemas.new(schemas) }

      context 'when schemas are not set' do
        context 'when schema is nil' do
          let(:schemas) { nil }

          it 'should be valid' do
            expect(catalog_schemas.valid?).to be true
            expect(catalog_schemas.errors.messages.length).to be 0
            expect(catalog_schemas.create_instance).to be_nil
            expect(catalog_schemas.update_instance).to be_nil
          end
        end

        context 'when schema is an empty hash' do
          let(:schemas) { {} }

          it 'should be valid' do
            expect(catalog_schemas.valid?).to be true
            expect(catalog_schemas.errors.messages.length).to be 0
            expect(catalog_schemas.create_instance).to be_nil
            expect(catalog_schemas.update_instance).to be_nil
          end
        end
      end

      context 'service instance schemas' do
        context 'schemas' do
          context 'when services instance is nil' do
            let(:schemas) { { 'service_instance' => nil } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
              expect(catalog_schemas.errors.messages.length).to be 0
              expect(catalog_schemas.create_instance).to be_nil
              expect(catalog_schemas.update_instance).to be_nil
            end
          end

          context 'when services instance is an empty hash' do
            let(:schemas) { { 'service_instance' => {} } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
              expect(catalog_schemas.errors.messages.length).to be 0
              expect(catalog_schemas.create_instance).to be_nil
              expect(catalog_schemas.update_instance).to be_nil
            end
          end

          context 'when service instance is not a hash' do
            let(:schemas) { { 'service_instance' => true } }

            it 'should be invalid and return an error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to eq 'Schemas service_instance must be a hash, but has value true'
            end
          end

          context 'when schemas is not a hash' do
            let(:schemas) { true }

            it 'should be invalid and return an error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to eq 'Schemas must be a hash, but has value true'
            end
          end
        end

        context 'when it has a service_instance create schema' do
          context 'when the schema structure is valid' do
            let(:schemas) do
              { 'service_instance' => {
                'create' => {
                  'parameters' => {
                    '$schema' => 'http://json-schema.org/draft-04/schema#',
                    'type' => 'object' }
                }
              } }
            end

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should set up a create_instance schema' do
              expect(catalog_schemas.create_instance).to be_an_instance_of(Schema)
            end
          end

          context 'when service_instance has a nil create schema' do
            let(:schemas) { { 'service_instance' => { 'create' => nil } } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should not set up a create_instance schema' do
              expect(catalog_schemas.create_instance).to be_nil
            end
          end

          context 'when service_instance create schema parameters are nil' do
            let(:schemas) { { 'service_instance' => { 'create' => { 'parameters' => nil } } } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should not set up a create_instance schema' do
              expect(catalog_schemas.create_instance).to be_nil
            end
          end

          context 'when the create instance schema parameters properties is not a hash' do
            let(:schemas) do
              { 'service_instance' => {
                  'create' => {
                    'parameters' => {
                      '$schema' => 'http://json-schema.org/draft-04/schema#',
                      'type' => 'object',
                      'properties' => true }
                  }
              } }
            end

            it 'should be invalid and error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to match 'Schema service_instance.create.parameters is not valid'
            end
          end

          context 'when service_instance create is not a hash' do
            let(:schemas) { { 'service_instance' => { 'create' => true } } }

            it 'should not be valid' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.create_instance).to be_nil
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'must be a hash, but has value true'
            end
          end

          context 'when service_instance create parameters is not a hash' do
            let(:schemas) { { 'service_instance' => { 'create' => { 'parameters' => true } } } }

            it 'should not be valid' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.create_instance).to be_nil
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'must be a hash, but has value true'
            end
          end
        end

        context 'when catalog has an update schema' do
          context 'and the schema structure is valid' do
            let(:schemas) {
              {
                'service_instance' => {
                  'update' => {
                    'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' }
                  }
                }
              }
            }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should set up an update_instance schema' do
              expect(catalog_schemas.update_instance).to be_an_instance_of(Schema)
            end
          end

          context 'when service_instance has a nil update schema' do
            let(:schemas) { { 'service_instance' => { 'update' => nil } } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should not set up a create_instance schema' do
              expect(catalog_schemas.update_instance).to be_nil
            end
          end

          context 'when service_instance update schema parameters are nil' do
            let(:schemas) { { 'service_instance' => { 'update' => { 'parameters' => nil } } } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should not set up a update_instance schema' do
              expect(catalog_schemas.update_instance).to be_nil
            end
          end

          context 'when the update instance schema properties is a boolean' do
            let(:schemas) do
              {
                'service_instance' => {
                  'update' => {
                    'parameters' => {
                      '$schema' => 'http://json-schema.org/draft-04/schema#',
                      'type' => 'object',
                      'properties' => true
                    }
                  }
                }
              }
            end

            it 'should not be valid and return an error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'Schema service_instance.update.parameters is not valid'
            end
          end

          context 'when service_instance update is not a hash' do
            let(:schemas) { { 'service_instance' => { 'update' => true } } }

            it 'should not be valid' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.update_instance).to be_nil
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'must be a hash, but has value true'
            end
          end

          context 'when service_instance update parameters is not a hash' do
            let(:schemas) { { 'service_instance' => { 'update' => { 'parameters' => true } } } }

            it 'should not be valid' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.update_instance).to be_nil
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'must be a hash, but has value true'
            end
          end
        end
      end

      context 'service binding' do
        context 'when catalog has schemas' do
          let(:schemas) { { 'service_binding' => {} } }

          context 'when services binding is nil' do
            let(:schemas) { { 'service_binding' => nil } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
              expect(catalog_schemas.errors.messages.length).to be 0
              expect(catalog_schemas.create_binding).to be_nil
            end
          end

          context 'when services binding is an empty hash' do
            let(:schemas) { { 'service_binding' => {} } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
              expect(catalog_schemas.errors.messages.length).to be 0
              expect(catalog_schemas.create_binding).to be_nil
            end
          end

          context 'when service binding is not a hash' do
            let(:schemas) { { 'service_binding' => true } }

            it 'should be invalid and return an error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to eq 'Schemas service_binding must be a hash, but has value true'
            end
          end

          context 'when schemas is not a hash' do
            let(:schemas) { true }

            it 'should be invalid and return an error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to eq 'Schemas must be a hash, but has value true'
            end
          end
        end

        context 'when it has a service_binding create schema' do
          context 'when the schema structure is valid' do
            let(:schemas) do
              { 'service_binding' => {
                'create' => {
                  'parameters' => {
                    '$schema' => 'http://json-schema.org/draft-04/schema#',
                    'type' => 'object' }
                }
              } }
            end

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should set up a service_binding schema' do
              expect(catalog_schemas.create_binding).to be_an_instance_of(Schema)
            end
          end

          context 'when service_binding has a nil create schema' do
            let(:schemas) { { 'service_binding' => { 'create' => nil } } }

            it 'should be valid' do
              expect(catalog_schemas.valid?).to be true
            end

            it 'should not set up a create_binding schema' do
              expect(catalog_schemas.create_binding).to be_nil
            end
          end

          context 'when the create binding schema parameters properties is not a hash' do
            let(:schemas) do
              { 'service_binding' => {
                  'create' => {
                    'parameters' => {
                      '$schema' => 'http://json-schema.org/draft-04/schema#',
                      'type' => 'object',
                      'properties' => true }
                  }
              } }
            end

            it 'should be invalid and error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to match 'Schema service_binding.create.parameters is not valid'
            end
          end

          context 'when the create binding schema parameters properties is not a hash' do
            let(:schemas) do
              { 'service_binding' => {
                  'create' => {
                    'parameters' => {
                      '$schema' => 'http://json-schema.org/draft-04/schema#',
                      'type' => 'object',
                      'properties' => true }
                  }
              } }
            end

            it 'should be invalid and error' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.errors.messages.length).to be 1
              expect(catalog_schemas.errors.messages.first).to match 'Schema service_binding.create.parameters is not valid'
            end
          end

          context 'when service_binding create is not a hash' do
            let(:schemas) { { 'service_binding' => { 'create' => true } } }

            it 'should not be valid' do
              expect(catalog_schemas.valid?).to be false
              expect(catalog_schemas.create_binding).to be_nil
              expect(catalog_schemas.errors.messages.length).to eq 1
              expect(catalog_schemas.errors.messages.first).to match 'must be a hash, but has value true'
            end
          end
        end
      end
    end
  end
end
