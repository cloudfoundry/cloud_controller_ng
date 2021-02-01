require 'lightweight_spec_helper'
require 'services/service_brokers/v2/schema'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Schema do
    let(:schema) { Schema.new(raw_schema) }

    describe '#to_json' do
      let(:raw_schema) {
        {
          '$schema' => 'http://json-schema.org/draft-04/schema#',
          :properties => { foo: { type: 'string' } },
          :required => ['foo']
        }
      }

      it 'converts a hash into json' do
        expect(schema.to_json).to eq '{"$schema":"http://json-schema.org/draft-04/schema#",'\
          '"properties":{"foo":{"type":"string"}},'\
          '"required":["foo"]}'
      end
    end

    describe 'schema validations' do
      let(:draft_schema) { "http://json-schema.org/#{version}/schema#" }
      let(:raw_schema) { { '$schema' => draft_schema } }

      context 'when the schema is compliant to JSON Schema draft04' do
        let(:version) { 'draft-04' }
        let(:raw_schema) { { '$schema' => draft_schema } }

        it 'should be valid' do
          expect(schema.validate).to be true
          expect(schema.errors.full_messages.length).to be 0
        end
      end

      context 'when the schema is compliant to JSON Schema draft06' do
        let(:version) { 'draft-06' }
        let(:raw_schema) { { '$schema' => draft_schema } }

        it 'should be valid' do
          expect(schema.validate).to be true
          expect(schema.errors.full_messages.length).to eq 0
        end
      end

      context 'when the schema has an internal reference' do
        let(:raw_schema) {
          {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            properties: {
              foo: { type: 'integer' },
              bar: { '$ref': '#/properties/foo' }
            }
          }
        }

        it 'should be valid' do
          expect(schema.validate).to be true
          expect(schema.errors.full_messages.length).to be 0
        end
      end

      describe 'metaschema errors' do
        context 'when JSON::Validator returns an error' do
          let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', properties: true } }

          before do
            allow(JSON::Validator).to receive(:fully_validate).and_return([{ message: 'whoops' }])
          end

          it 'add a schema error message with a wrapped error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): whoops' \
          end
        end

        context 'when JSON::Validator raises an error' do
          let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', properties: true } }

          before do
            allow(JSON::Validator).to receive(:fully_validate).and_raise('uh oh')
          end

          it 'add a schema error message with the error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to eq 'uh oh'
          end
        end

        context 'when there are multiple errors' do
          let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', properties: true, anyOf: true } }

          it 'should have more than one error message' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 2
            expect(schema.errors.full_messages.first).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
              'The property \'#/properties\' of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#'
            expect(schema.errors.full_messages.last).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
              'The property \'#/anyOf\' of type boolean did not match the following type: array in schema http://json-schema.org/draft-04/schema#'
          end
        end
      end

      describe 'open service broker restrictions' do
        context 'when the schema raises a SchemaError' do
          let(:raw_schema) { { '$schema' => 'blahblahblah' } }

          it 'should a schema error message with the error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to eq 'Custom meta schemas are not supported.'
          end
        end

        context 'when the schema includes an external reference' do
          context 'when $ref is an external reference' do
            let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', '$ref' => 'http://example.com/ref' } }

            it 'should add a schema error message with the error' do
              expect(schema.validate).to be false
              expect(schema.errors.full_messages.length).to eq 1
              expect(schema.errors.full_messages.first).to eq 'No external references are allowed: Read of URI at http://example.com/ref refused'
            end
          end

          context 'when custom schema is not recognized by the library' do
            let(:raw_schema) { { '$schema' => 'http://example.com/schema' } }

            it 'should not be valid' do
              expect(schema.validate).to be false
              expect(schema.errors.full_messages.length).to eq 1
              expect(schema.errors.full_messages.first).to match 'Custom meta schemas are not supported.'
            end
          end
        end

        context 'when the schema has an external file reference' do
          let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', '$ref': 'path/to/schema.json' } }

          it 'should not be valid' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'No external references are allowed.+path/to/schema.json'
          end
        end

        context 'when the schema has an unknown parse error' do
          let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#' } }

          before do
            allow(JSON::Validator).to receive(:validate!).and_raise('some unknown error')
          end

          it 'should a schema error message with the error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to eq 'some unknown error'
          end
        end
      end

      describe 'validation ordering' do
        context 'when an invalid schema has size/schema/draft04/reference validations errors' do
          let(:raw_schema) do
            schema = create_schema_of_size(65 * 1024)
            schema.delete('$schema')
            schema['properties'] = true
            schema['$raw'] = 'https://example.com/ref'
            schema
          end

          it 'only returns schema size error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
          end
        end

        context 'when an invalid schema has schema/draft04/reference validations errors' do
          let(:raw_schema) do
            schema = create_schema_of_size(1024)
            schema.delete('$schema')
            schema['properties'] = true
            schema['$raw'] = 'https://example.com/ref'
            schema
          end

          it 'only returns schema not present error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Schema must have $schema key but was not present'
          end
        end

        context 'when an invalid schema has draft04/reference validations errors' do
          let(:raw_schema) do
            schema = create_schema_of_size(1024)
            schema['properties'] = true
            schema['$ref'] = 'https://example.com/ref'
            schema
          end

          it 'only returns draft04 error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Must conform to JSON Schema Draft 04'
          end
        end

        context 'when an invalid schema has reference validations errors' do
          let(:raw_schema) do
            schema = create_schema_of_size(1024)
            schema['$ref'] = 'https://example.com/ref'
            schema
          end

          it 'only returns external reference error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'No external references are allowed'
          end
        end
      end

      describe 'schema sizes' do
        context 'that are valid' do
          {
            'well below the limit': 1,
            'just below the limit': 63,
            'on the limit': 64,
          }.each do |desc, size_in_kb|
            context "when the schema json is #{desc}" do
              let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

              it 'should be valid' do
                expect(schema.validate).to be true
                expect(schema.errors.full_messages.length).to eq 0
              end
            end
          end
        end

        context 'that are invalid' do
          {
            'just above the limit': 65,
            'well above the limit': 10 * 1024,
          }.each do |desc, size_in_kb|
            context "when the schema json is #{desc}" do
              let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

              it 'returns one error' do
                expect(schema.validate).to be false
                expect(schema.errors.full_messages.length).to eq 1
                expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
              end
            end
          end
        end
      end

      context 'when neither draft06 nor draft04 schema has been specified' do
        context 'when the schema is a different draft version' do
          let(:version) { 'some-random-schema' }

          it 'should return a helpful error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Custom meta schemas are not supported'
          end
        end

        context 'when no schema has been specified' do
          let(:raw_schema) { {} }

          it 'should return a helpful error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Schema must have $schema key but was not present'
          end
        end

        context 'when an unknown schema has been specified' do
          let(:draft_schema) { 'http://example.com/someschema' }

          it 'should return a helpful error' do
            expect(schema.validate).to be false
            expect(schema.errors.full_messages.length).to eq 1
            expect(schema.errors.full_messages.first).to match 'Custom meta schemas are not supported'
          end
        end
      end
    end
    def create_schema_of_size(bytes)
      surrounding_bytes = 62
      {
        '$schema' => 'http://json-schema.org/draft-04/schema#',
        'foo' => 'x' * (bytes - surrounding_bytes)
      }
    end
  end
end
