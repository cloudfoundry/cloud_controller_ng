require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe 'schema validation' do
    describe 'ServiceInstanceSchema' do
      subject do
        service_instance_schema = ServiceInstanceSchema.new(instance)
        service_instance_schema.valid?
        service_instance_schema
      end
      context 'create' do
        context 'when not set' do
          let(:instance) { {} }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:create) { should be nil }
        end

        context 'when set to an empty hash' do
          let(:instance) { { 'create' => {} } }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:create) { should_not be nil }
        end

        context 'when it is not hash ' do
          let(:instance) { { 'create' => true } }

          its(:valid?) { should be false }
          its('errors.messages') { should have(1).items }
          its('errors.messages.first') { should eq 'Schemas service_instance.create must be a hash, but has value true' }
          its(:create) { should be nil }
        end

        context 'when it not valid' do
          let(:instance) { { 'create' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }
          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { should be false }
          its('errors.nested_errors') { should have(1).items }
        end
      end

      context 'update' do
        context 'when not set' do
          let(:instance) { {} }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:update) { should be nil }
        end

        context 'when set to an empty hash' do
          let(:instance) { { 'update' => {} } }
          its(:valid?) { should be true }
          its(:errors) { should be_empty }
          its(:update) { should_not be nil }
        end

        context 'when it is not hash ' do
          let(:instance) { { 'update' => true } }

          its(:valid?) { should be false }
          its('errors.messages') { should have(1).items }
          its('errors.messages.first') { should eq 'Schemas service_instance.update must be a hash, but has value true' }
          its(:update) { should be nil }
        end

        context 'when it not valid' do
          let(:instance) { { 'update' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }
          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { should be false }
          its('errors.nested_errors') { should have(1).items }
        end
      end
    end
  end
end
