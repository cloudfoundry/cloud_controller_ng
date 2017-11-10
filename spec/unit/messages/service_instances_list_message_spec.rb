require 'spec_helper'
require 'messages/service_instances/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ServiceInstancesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'name',
          'names' => 'rabbitmq, redis,mysql'
        }
      end

      it 'returns the correct ServiceInstancesListMessage' do
        message = ServiceInstancesListMessage.from_params(params)

        expect(message).to be_a(ServiceInstancesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('name')
        expect(message.names).to match_array(['mysql', 'rabbitmq', 'redis'])
      end

      it 'converts requested keys to symbols' do
        message = ServiceInstancesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = ServiceInstancesListMessage.new({
            page: 1,
            per_page: 5,
            order_by: 'created_at',
            names: ['rabbitmq', 'redis']
          })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = ServiceInstancesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ServiceInstancesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
