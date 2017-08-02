require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Schema do
    describe 'validating schema' do
      subject do
        schema = Schema.new(raw_schema)
        schema.validate
        schema
      end

      let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }

      context 'when attrs have an invalid value as type' do
        let(:raw_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object', 'properties' => { 'test' => { 'type' => 'notatype' } } } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') {
          should eq 'Must conform to JSON Schema Draft 04: ' \
                          "The property '#/properties/test/type' of type string did not match one or more of the required schemas in schema http://json-schema.org/draft-04/schema#"
        }
      end

      context 'when schema has multiple invalid types' do
        let(:raw_schema) {
          {
              '$schema' => 'http://json-schema.org/draft-04/schema#',
              'type' => 'object',
              'properties' => {
                  'test' => { 'type' => 'notatype' },
                  'b2' => { 'type' => 'alsonotatype' }
              }
          }
        }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(2).items }
        its('errors.full_messages.first') {
          should eq 'Must conform to JSON Schema Draft 04: ' \
                          "The property '#/properties/test/type' of type string did not match one or more of the required schemas in schema http://json-schema.org/draft-04/schema#"
        }
        its('errors.full_messages.last') {
          should eq 'Must conform to JSON Schema Draft 04: ' \
                          "The property '#/properties/b2/type' of type string did not match one or more of the required schemas in schema http://json-schema.org/draft-04/schema#"
        }
      end

      context 'when the schema does not conform to JSON Schema Draft 04' do
        let(:raw_schema) { { 'type' => 'object', 'properties': true } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') {
          should eq "Must conform to JSON Schema Draft 04: The property '#/properties' " \
                          'of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#'
        }
      end

      context 'when the schema does not conform to JSON Schema Draft 04 with multiple problems' do
        let(:raw_schema) { { 'type' => 'object', 'properties': true, 'anyOf': true } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(2).items }
        its('errors.full_messages.first') {
          should eq 'Must conform to JSON Schema Draft 04: ' \
                          'The property \'#/properties\' of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#'
        }
        its('errors.full_messages.second') {
          should eq 'Must conform to JSON Schema Draft 04: ' \
                          'The property \'#/anyOf\' of type boolean did not match the following type: array in schema http://json-schema.org/draft-04/schema#'
        }
      end

      context 'when the schema has an external schema' do
        let(:raw_schema) { { 'type' => 'object', '$schema': 'http://example.com/schema' } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') {
          should eq 'Custom meta schemas are not supported.'
        }
      end

      context 'when the schema has an external uri reference' do
        let(:raw_schema) { { 'type' => 'object', '$ref': 'http://example.com/ref' } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') {
          should match 'No external references are allowed.+http://example.com/ref'
        }
      end

      context 'when the schema has an external file reference' do
        let(:raw_schema) { { 'type' => 'object', '$ref': 'path/to/schema.json' } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') {
          should match 'No external references are allowed.+path/to/schema.json'
        }
      end

      context 'when the schema has an internal reference' do
        let(:raw_schema) {
          {
              'type' => 'object',
              'properties': {
                  'foo': { 'type': 'integer' },
                  'bar': { '$ref': '#/properties/foo' }
              }
          }
        }

        its(:validate) { should be true }
        its(:errors) { should be_empty }
      end

      context 'when the schema has multiple valid constraints ' do
        let(:raw_schema) {
          {
              :'$schema' => 'http://json-schema.org/draft-04/schema#',
              'type' => 'object',
              :properties => { 'foo': { 'type': 'string' } },
              :required => ['foo']
          }
        }

        its(:to_json) {
          should eq(
            {
                :'$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object',
                :properties => { foo: { type: 'string' } },
                :required => ['foo']
            }.to_json
                 )
        }
        its(:validate) { should be true }
        its(:errors) { should be_empty }
      end

      describe 'schema sizes' do
        context 'that are valid' do
          {
              'well below the limit': 1,
              'just below the limit': 63,
              'on the limit': 64,
          }.each do |desc, size_in_kb|
            context "when the schema is #{desc}" do
              let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

              its(:validate) { should be true }
              its(:errors) { should be_empty }
            end
          end
        end

        context 'that are invalid' do
          {
              'just above the limit': 65,
              'well above the limit': 10 * 1024,
          }.each do |desc, size_in_kb|
            context "when the schema is #{desc}" do
              let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

              its(:validate) { should be false }
              its('errors.full_messages') { should have(1).items }
              its('errors.full_messages.first') { should eq 'To json Must not be larger than 64KB' }
            end
          end
        end
      end

      context 'when the schema does not have a type field' do
        let(:raw_schema) { { '$schema': 'http://json-schema.org/draft-04/schema#' } }

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') { should eq 'must have field "type", with value "object"' }
      end

      context 'when the schema has an unknown parse error' do
        before do
          allow(JSON::Validator).to receive(:validate!) { raise 'some unknown error' }
        end

        its(:validate) { should be false }
        its('errors.full_messages') { should have(1).items }
        its('errors.full_messages.first') { should eq 'some unknown error' }
      end

      describe 'validation ordering' do
        context 'when an invalid schema fails multiple validations' do
          context 'schema size and schema type' do
            let(:raw_schema) do
              schema = create_schema_of_size(64 * 1024)
              schema['type'] = 'notobject'
              schema
            end

            its(:validate) { should be false }
            its('errors.full_messages') { should have(1).items }
            its('errors.full_messages.first') { should match 'Must not be larger than 64KB' }
          end

          context 'schema size and external reference' do
            let(:raw_schema) do
              schema = create_schema_of_size(64 * 1024)
              schema['$ref'] = 'http://example.com/ref'
              schema
            end

            its(:validate) { should be false }
            its('errors.full_messages') { should have(1).items }
            its('errors.full_messages.first') { should match 'Must not be larger than 64KB' }
          end

          context 'schema size and does not conform to Json Schema Draft 4' do
            let(:raw_schema) do
              schema = create_schema_of_size(64 * 1024)
              schema['properties'] = true
              schema
            end

            its(:validate) { should be false }
            its('errors.full_messages') { should have(1).items }
            its('errors.full_messages.first') { should match 'Must not be larger than 64KB' }
          end

          context 'schema type and does not conform to JSON Schema Draft 4' do
            let(:raw_schema) { { 'type' => 'notobject', 'properties' => true } }

            its(:validate) { should be false }
            its('errors.full_messages') { should have(1).items }
            its('errors.full_messages.first') { should match 'must have field "type", with value "object"' }
          end

          context 'does not conform to JSON Schema Draft 4 and external references' do
            let(:raw_schema) { { 'type' => 'object', 'properties' => true, '$ref' => 'http://example.com/ref' } }

            its(:validate) { should be false }
            its('errors.full_messages') { should have(1).items }
            its('errors.full_messages.first') {
              should match 'Must conform to JSON Schema Draft 04: ' \
                  'The property \'#/properties\' of type boolean did not match the following type: ' \
                  'object in schema http://json-schema.org/draft-04/schema#'
            }
          end
        end
      end

      def create_schema_of_size(bytes)
        surrounding_bytes = 26
        {
            'type' => 'object',
            'foo' => 'x' * (bytes - surrounding_bytes)
        }
      end
    end
  end
end
