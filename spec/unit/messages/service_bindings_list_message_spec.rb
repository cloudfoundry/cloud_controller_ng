require 'spec_helper'
require 'messages/service_bindings_list_message'

module VCAP::CloudController
  RSpec.describe ServiceBindingsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
          'app_guids' => 'app-guid-1, app-guid-2,app-guid-3',
          'service_instance_guids' => 'service-instance-1, service-instance-2,service-instance-3'
        }
      end

      it 'returns the correct ServiceBindingsListMessage' do
        message = ServiceBindingsListMessage.from_params(params)

        expect(message).to be_a(ServiceBindingsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.app_guids).to eq(['app-guid-1', 'app-guid-2', 'app-guid-3'])
        expect(message.service_instance_guids).to match_array(['service-instance-1', 'service-instance-2', 'service-instance-3'])
      end

      it 'converts requested keys to symbols' do
        message = ServiceBindingsListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
        expect(message.requested?(:service_instance_guids)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = ServiceBindingsListMessage.new({
            page: 1,
            per_page: 5,
            order_by: 'created_at',
            app_guids: 'app-guid-1, app-guid2',
            service_instance_guids: 'service-instance-1, service-instance-2'
          })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = ServiceBindingsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ServiceBindingsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
