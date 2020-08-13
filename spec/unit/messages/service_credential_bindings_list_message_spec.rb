require 'spec_helper'
require 'messages/service_credential_bindings_list_message'

module VCAP::CloudController
  RSpec.describe ServiceCredentialBindingsListMessage do
    subject(:message) { described_class.from_params(params) }

    let(:params) do
      {
        'page'      => 1,
        'per_page'  => 5,
        'order_by'  => 'created_at',
        'service_instance_guids' => 'service-instance-1-guid, service-instance-2-guid,service-instance-3-guid',
        'service_instance_names' => 'service-instance-1-name, service-instance-2-name,service-instance-3-name',
        'names' => 'name1, name2',
        'app_guids' => 'app-1-guid, app-2-guid,app-3-guid',
        'app_names' => 'app-1-name, app-2-name,app-3-name'
      }
    end

    describe '.from_params' do
      it 'returns the correct ServiceCredentialBindingsListMessage' do
        expect(message).to be_a(ServiceCredentialBindingsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.service_instance_guids).to match_array(['service-instance-1-guid', 'service-instance-2-guid', 'service-instance-3-guid'])
        expect(message.service_instance_names).to match_array(['service-instance-1-name', 'service-instance-2-name', 'service-instance-3-name'])
        expect(message.names).to match_array(['name1', 'name2'])
        expect(message.app_guids).to match_array(['app-1-guid', 'app-2-guid', 'app-3-guid'])
        expect(message.app_names).to match_array(['app-1-name', 'app-2-name', 'app-3-name'])
      end

      it 'converts requested keys to symbols' do
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:service_instance_guids)).to be_truthy
        expect(message.requested?(:service_instance_names)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
        expect(message.requested?(:app_names)).to be_truthy
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
        message = described_class.from_params({ foobar: 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
