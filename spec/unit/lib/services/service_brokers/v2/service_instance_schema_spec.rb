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

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:create) { is_expected.to be_nil }
        end

        context 'when set to an empty hash' do
          let(:instance) { { 'create' => {} } }

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:create) { is_expected.not_to be_nil }
        end

        context 'when it is not hash' do
          let(:instance) { { 'create' => true } }

          its(:valid?) { is_expected.to be false }
          its('errors.messages') { is_expected.to have(1).items }
          its('errors.messages.first') { is_expected.to eq 'Schemas service_instance.create must be a hash, but has value true' }
          its(:create) { is_expected.to be_nil }
        end

        context 'when it not valid' do
          let(:instance) { { 'create' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }

          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { is_expected.to be false }
          its('errors.nested_errors') { is_expected.to have(1).items }
        end
      end

      context 'update' do
        context 'when not set' do
          let(:instance) { {} }

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:update) { is_expected.to be_nil }
        end

        context 'when set to an empty hash' do
          let(:instance) { { 'update' => {} } }

          its(:valid?) { is_expected.to be true }
          its(:errors) { is_expected.to be_empty }
          its(:update) { is_expected.not_to be_nil }
        end

        context 'when it is not hash' do
          let(:instance) { { 'update' => true } }

          its(:valid?) { is_expected.to be false }
          its('errors.messages') { is_expected.to have(1).items }
          its('errors.messages.first') { is_expected.to eq 'Schemas service_instance.update must be a hash, but has value true' }
          its(:update) { is_expected.to be_nil }
        end

        context 'when it not valid' do
          let(:instance) { { 'update' => {} } }
          let(:validation_error) { VCAP::Services::ValidationErrors.new }

          before do
            validation_error.add('some error')
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:errors).and_return(validation_error)
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::ParametersSchema).to receive(:valid?).and_return(false)
          end

          its(:valid?) { is_expected.to be false }
          its('errors.nested_errors') { is_expected.to have(1).items }
        end
      end
    end
  end
end
