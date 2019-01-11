require 'spec_helper'
require 'messages/service_instances_list_message'

module VCAP::CloudController
  RSpec.describe ServiceInstancesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'name',
          'names' => 'rabbitmq, redis,mysql',
          'space_guids' => 'space-1, space-2, space-3',
        }
      end

      it 'returns the correct ServiceInstancesListMessage' do
        message = ServiceInstancesListMessage.from_params(params)

        expect(message).to be_a(ServiceInstancesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('name')
        expect(message.names).to match_array(['mysql', 'rabbitmq', 'redis'])
        expect(message.space_guids).to match_array(['space-1', 'space-2', 'space-3'])
      end

      it 'converts requested keys to symbols' do
        message = ServiceInstancesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = ServiceInstancesListMessage.from_params({
            page: 1,
            per_page: 5,
            order_by: 'created_at',
            names: ['rabbitmq', 'redis'],
            space_guids: ['space-1', 'space-2'],
          })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = ServiceInstancesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ServiceInstancesListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'names' do
        it 'validates names is an array' do
          message = ServiceInstancesListMessage.from_params names: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:names]).to include('must be an array')
        end
      end

      context 'space guids' do
        it 'validates space_guids is an array' do
          message = ServiceInstancesListMessage.from_params space_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:space_guids]).to include('must be an array')
        end
      end
    end
  end
end
