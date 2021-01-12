require 'lightweight_spec_helper'
require 'messages/service_credential_binding_list_message'

module VCAP::CloudController
  RSpec.describe ServiceCredentialBindingListMessage do
    subject(:message) { described_class.from_params(params) }

    let(:params) do
      {
        'page' => 1,
        'per_page' => 5,
        'order_by' => 'created_at',
        'service_instance_guids' => 'service-instance-1-guid, service-instance-2-guid, service-instance-3-guid',
        'service_instance_names' => 'service-instance-1-name, service-instance-2-name, service-instance-3-name',
        'service_plan_guids' => 'service-plan-1-guid, service-plan-2-guid, service-plan-3-guid',
        'service_plan_names' => 'service-plan-1-name, service-plan-2-name, service-plan-3-name',
        'service_offering_guids' => 'service-offering-1-guid, service-offering-2-guid, service-offering-3-guid',
        'service_offering_names' => 'service-offering-1-name, service-offering-2-name, service-offering-3-name',
        'names' => 'name1, name2',
        'app_guids' => 'app-1-guid, app-2-guid, app-3-guid',
        'app_names' => 'app-1-name, app-2-name, app-3-name',
        'type' => 'app',
        'include' => 'app,service_instance',
        'label_selector' => 'key=value'
      }
    end

    describe '.from_params' do
      it 'returns the correct ServiceCredentialBindingsListMessage' do
        expect(message).to be_a(ServiceCredentialBindingListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.service_instance_guids).to match_array(['service-instance-1-guid', 'service-instance-2-guid', 'service-instance-3-guid'])
        expect(message.service_instance_names).to match_array(['service-instance-1-name', 'service-instance-2-name', 'service-instance-3-name'])
        expect(message.service_plan_guids).to match_array(['service-plan-1-guid', 'service-plan-2-guid', 'service-plan-3-guid'])
        expect(message.service_plan_names).to match_array(['service-plan-1-name', 'service-plan-2-name', 'service-plan-3-name'])
        expect(message.service_offering_guids).to match_array(['service-offering-1-guid', 'service-offering-2-guid', 'service-offering-3-guid'])
        expect(message.service_offering_names).to match_array(['service-offering-1-name', 'service-offering-2-name', 'service-offering-3-name'])
        expect(message.names).to match_array(['name1', 'name2'])
        expect(message.app_guids).to match_array(['app-1-guid', 'app-2-guid', 'app-3-guid'])
        expect(message.app_names).to match_array(['app-1-name', 'app-2-name', 'app-3-name'])
        expect(message.type).to eq('app')
        expect(message.include).to match_array(['app', 'service_instance'])
      end

      it 'converts requested keys to symbols' do
        params.each do |key, _|
          expect(message.requested?(key.to_sym)).to be_truthy
        end
      end
    end

    describe '#valid?' do
      it 'returns true for valid fields' do
        message = described_class.from_params(params)
        expect(message).to be_valid
      end

      it 'returns true for empty fields' do
        message = described_class.from_params({})
        expect(message).to be_valid
      end

      it 'returns false for invalid fields' do
        message = described_class.from_params({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'type' do
        it 'returns true for valid types' do
          expect(described_class.from_params({ 'type' => 'app' })).to be_valid
          expect(described_class.from_params({ 'type' => 'key' })).to be_valid
        end

        it 'returns false for invalid types' do
          message = described_class.from_params({ 'type' => 'route' })
          expect(message).not_to be_valid
          expect(message.errors[:type]).to include("must be one of 'app', 'key'")
        end
      end

      context 'include' do
        it 'returns false for arbitrary values' do
          message = described_class.from_params({ 'include' => 'route' })
          expect(message).not_to be_valid
          expect(message.errors[:base]).to include(include("Invalid included resource: 'route'"))
        end

        it 'returns true for valid values' do
          message = described_class.from_params({ 'include' => 'app, service_instance' })
          expect(message).to be_valid
        end
      end

      it 'validates metadata requirements' do
        message = described_class.from_params({ 'label_selector' => '' }.with_indifferent_access)

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end

    describe 'order_by' do
      it 'allows name' do
        message = described_class.from_params(order_by: 'name')
        expect(message).to be_valid
      end
    end
  end
end
