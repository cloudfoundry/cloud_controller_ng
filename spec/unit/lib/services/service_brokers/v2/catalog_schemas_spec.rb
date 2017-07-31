require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'validating catalog schemas' do
      subject do
        catalog_schema = CatalogSchemas.new(attrs)
        catalog_schema.valid?
        catalog_schema
      end

      context 'service instance' do
        context 'when catalog has schemas' do
          let(:attrs) { { 'service_instance' => {} } }

          context 'when schemas is not set' do
            {
                'Schemas is nil': nil,
                'Schemas is empty': {},
                'Schemas service_instance is nil': { 'service_instance' => nil },
                'Schemas service_instance is empty': { 'service_instance' => {} },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas is invalid' do
            {
                'Schemas': true,
                'Schemas service_instance': { 'service_instance' => true }
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end
        end

        context 'when catalog has a create schema' do
          context 'and the schema structure is valid' do
            let(:attrs) { { 'service_instance' => { 'create' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } } } } }

            its(:create_instance) { should be_a(Schema) }
          end

          context 'and it has nil value' do
            {
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

          context 'when the create instance schema is not valid' do
            let(:attrs) {
              {
                  'service_instance' => {
                      'create' => {
                          'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object', 'properties' => true }
                      }
                  }
              }
            }
            let(:path) { 'service_instance.create.parameters' }

            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid" }
            its(:valid?) { should be false }
          end

          context 'when attrs have a missing key' do
            {
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

          context 'when attrs has a potentially dangerous uri' do
            let(:path) { 'service_instance.create.parameters' }
            let(:attrs) {
              {
                  'service_instance' => {
                      'create' => {
                          'parameters' => 'https://example.com/hax0r'
                      }
                  }
              }
            }

            its(:create_instance) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "Schemas #{path} must be a hash, but has value \"https://example.com/hax0r\"" }
            its(:valid?) { should be false }
          end
        end

        context 'when catalog has an update schema' do
          context 'and the schema structure is valid' do
            let(:attrs) {
              {
                  'service_instance' => {
                      'update' => {
                          'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' }
                      }
                  }
              }
            }

            its(:update_instance) { should be_a(Schema) }
          end

          context 'when attrs have nil value' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => nil } },
                'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when the update instance schema is not valid' do
            let(:attrs) {
              {
                  'service_instance' => {
                      'update' => {
                          'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object', 'properties' => true }
                      }
                  }
              }
            }
            let(:path) { 'service_instance.update.parameters' }

            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid" }
            its(:valid?) { should be false }
          end

          context 'when attrs have a missing key' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have an invalid type' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => true } },
                'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          # TODO: Look into schema path is not valid error tests

          context 'when attrs has a potentially dangerous uri' do
            let(:path) { 'service_instance.update.parameters' }
            let(:attrs) {
              {
                  'service_instance' => {
                      'update' => {
                          'parameters' => 'https://example.com/hax0r'
                      }
                  }
              }
            }

            its(:update_instance) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "Schemas #{path} must be a hash, but has value \"https://example.com/hax0r\"" }
            its(:valid?) { should be false }
          end
        end
      end
    end
  end
end
