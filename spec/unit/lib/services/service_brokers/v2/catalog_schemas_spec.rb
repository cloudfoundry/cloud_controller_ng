require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'initializing' do
      let(:create_instance_schema) { { '$schema': 'http://json-schema.org/draft-04/schema#' } }
      let(:attrs) { { 'service_instance' => { 'create' => { 'parameters' => create_instance_schema } } } }
      subject { CatalogSchemas.new(attrs) }

      its(:create_instance) { should eq create_instance_schema }
      its(:errors) { should be_empty }
      its(:valid?) { should be true }

      context 'when attrs have nil value' do
        {
          'Schemas': nil,
          'Schemas service_instance': { 'service_instance' => nil },
          'Schemas service_instance.create': { 'service_instance' => { 'create' => nil } },
          'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => nil } } },
        }.each do |name, test|
          context "for property #{name}" do
            let(:attrs) { test }

            its(:create_instance) { should be_nil }
            its(:errors) { should be_empty }
            its(:valid?) { should be true }
          end
        end
      end

      context 'when attrs have a missing key' do
        {
          'Schemas': {},
          'Schemas service_instance': { 'service_instance' => {} },
          'Schemas service_instance.create': { 'service_instance' => { 'create' => {} } },
        }.each do |name, test|
          context "for property #{name}" do
            let(:attrs) { test }

            its(:create_instance) { should be_nil }
            its(:errors) { should be_empty }
            its(:valid?) { should be true }
          end
        end
      end

      context 'when attrs have an invalid type' do
        {
          'Schemas': true,
          'Schemas service_instance': { 'service_instance' => true },
          'Schemas service_instance.create': { 'service_instance' => { 'create' => true } },
          'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => true } } },
        }.each do |name, test|
          context "for property #{name}" do
            let(:attrs) { test }

            its(:create_instance) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
            its(:valid?) { should be false }
          end
        end
      end

      context 'when the schema does not conform to JSON Schema Draft 04' do
        let(:create_instance_schema) { { 'properties': true } }
        its(:valid?) { should be false }
        its('errors.messages') { should have(1).items }
        its('errors.messages.first') {
          should match 'Schema service_instance.create.parameters is not valid\. Must conform to JSON Schema Draft 04'
        }
      end

      context 'when the schema has an external schema' do
        let(:create_instance_schema) { { '$schema': 'http://example.com/schema' } }
        its(:valid?) { should be false }
        its('errors.messages') { should have(1).items }
        its('errors.messages.first') {
          should match 'Schema service_instance.create.parameters is not valid\. Custom meta schemas are not supported.+http://example.com/schema'
        }
      end

      context 'when the schema has an external uri reference' do
        let(:create_instance_schema) { { '$ref': 'http://example.com/ref' } }
        its(:valid?) { should be false }
        its('errors.messages') { should have(1).items }
        its('errors.messages.first') {
          should match 'Schema service_instance.create.parameters is not valid\. No external references are allowed.+http://example.com/ref'
        }
      end

      context 'when the schema has an external file reference' do
        let(:create_instance_schema) { { '$ref': 'path/to/schema.json' } }
        its(:valid?) { should be false }
        its('errors.messages') { should have(1).items }
        its('errors.messages.first') {
          should match 'Schema service_instance.create.parameters is not valid\. No external references are allowed.+path/to/schema.json'
        }
      end

      context 'when the schema has an internal reference' do
        let(:create_instance_schema) {
          {
            'properties': {
              'foo': { 'type': 'integer' },
              'bar': { '$ref': '#/properties/foo' }
            }
          }
        }
        its(:valid?) { should be true }
        its(:errors) { should be_empty }
      end

      context 'when the schema has an unknown parse error' do
        before do
          allow(JSON::Validator).to receive(:validate!) { raise 'some unknown error' }
        end

        its(:valid?) { should be false }
        its('errors.messages') { should have(1).items }
        its('errors.messages.first') { should match 'Schema service_instance.create.parameters is not valid\.+ some unknown error' }
      end

      context 'when the schema has multiple valid constraints ' do
        let(:create_instance_schema) {
          { '$schema': 'http://json-schema.org/draft-04/schema#',
            'properties': {
              'foo': {
                'type': 'string'
              }
            },
            'required': ['foo']
          }
        }
        its(:valid?) { should be true }
      end
    end
  end
end
