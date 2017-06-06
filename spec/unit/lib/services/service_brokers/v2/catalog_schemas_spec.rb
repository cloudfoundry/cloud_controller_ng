require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'initializing' do
      let(:create_instance_schema) { { '$schema': 'example.com/schema' } }
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
    end
  end
end
