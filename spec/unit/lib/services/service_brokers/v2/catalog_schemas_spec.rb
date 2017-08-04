require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'validating catalog schemas' do
      subject do
        catalog_schema = CatalogSchemas.new(schemas)
        catalog_schema.valid?
        catalog_schema
      end

      context 'when schemas are not set' do
        {
          'Schemas is nil': nil,
          'Schemas is empty': {},
        }.each do |name, test|
          context "for property #{name}" do
            let(:schemas) { test }

            its(:create_instance) { should be_nil }
            its(:update_instance) { should be_nil }
            its(:errors) { should be_empty }
            its(:valid?) { should be true }
          end
        end
      end

      context 'service instance' do
        context 'when catalog has schemas' do
          let(:schemas) { { 'service_instance' => {} } }

          context 'when schemas are not set' do
            {
              'Schemas service_instance is nil': { 'service_instance' => nil },
              'Schemas service_instance is empty': { 'service_instance' => {} },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_instance) { should be_nil }
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
                let(:schemas) { test }

                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end
        end

        context 'when catalog has a create schema' do
          context 'and the schema structure is valid' do
            let(:schemas) { { 'service_instance' => { 'create' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } } } } }

            its(:create_instance) { should be_a(Schema) }
          end

          context 'and it has nil value' do
            {
              'Schemas service_instance.create': { 'service_instance' => { 'create' => nil } },
              'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when the create instance schema is not valid' do
            let(:schemas) {
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

          context 'when schemas have a missing key' do
            {
              'Schemas service_instance.create': { 'service_instance' => { 'create' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas have an invalid type' do
            {
              'Schemas service_instance.create': { 'service_instance' => { 'create' => true } },
              'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_instance) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          context 'when schemas has a potentially dangerous uri' do
            let(:path) { 'service_instance.create.parameters' }
            let(:schemas) {
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
            let(:schemas) {
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

          context 'when schemas have nil value' do
            {
              'Schemas service_instance.update': { 'service_instance' => { 'update' => nil } },
              'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when the update instance schema is not valid' do
            let(:schemas) {
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

          context 'when schemas have a missing key' do
            {
              'Schemas service_instance.update': { 'service_instance' => { 'update' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas have an invalid type' do
            {
              'Schemas service_instance.update': { 'service_instance' => { 'update' => true } },
              'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:update_instance) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          context 'when schemas has a potentially dangerous uri' do
            let(:path) { 'service_instance.update.parameters' }
            let(:schemas) {
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

      context 'service binding' do
        context 'when catalog has schemas' do
          let(:schemas) { { 'service_binding' => {} } }

          context 'when schema is not set' do
            {
              'Schemas service_binding is nil': { 'service_binding' => nil },
              'Schemas service_binding is empty': { 'service_binding' => {} },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_instance) { should be_nil }
                its(:update_instance) { should be_nil }
                its(:create_binding) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas is invalid' do
            {
              'Schemas': true,
              'Schemas service_binding': { 'service_binding' => true }
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end
        end

        context 'when catalog has a create schema' do
          context 'and the schema structure is valid' do
            let(:schemas) { { 'service_binding' => { 'create' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } } } } }

            its(:create_binding) { should be_a(Schema) }
          end

          context 'and it has nil value' do
            {
              'Schemas service_binding.create': { 'service_binding' => { 'create' => nil } },
              'Schemas service_binding.create.parameters': { 'service_binding' => { 'create' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_binding) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when the create binding schema is not valid' do
            let(:schemas) {
              {
                'service_binding' => {
                  'create' => {
                    'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object', 'properties' => true }
                  }
                }
              }
            }
            let(:path) { 'service_binding.create.parameters' }

            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid" }
            its(:valid?) { should be false }
          end

          context 'when schemas have a missing key' do
            {
              'Schemas service_binding.create': { 'service_binding' => { 'create' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_binding) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas have an invalid type' do
            {
              'Schemas service_binding.create': { 'service_binding' => { 'create' => true } },
              'Schemas service_binding.create.parameters': { 'service_binding' => { 'create' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:schemas) { test }

                its(:create_binding) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          context 'when schemas has a potentially dangerous uri' do
            let(:path) { 'service_binding.create.parameters' }
            let(:schemas) {
              {
                'service_binding' => {
                  'create' => {
                    'parameters' => 'https://example.com/hax0r'
                  }
                }
              }
            }

            its(:create_binding) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "Schemas #{path} must be a hash, but has value \"https://example.com/hax0r\"" }
            its(:valid?) { should be false }
          end
        end
      end
    end
  end
end
