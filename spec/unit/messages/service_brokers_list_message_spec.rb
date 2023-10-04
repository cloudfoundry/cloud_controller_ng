require 'spec_helper'
require 'messages/service_brokers_list_message'

module VCAP::CloudController
  RSpec.describe ServiceBrokersListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'space_guids' => 'space-guid-1,space-guid-2,space-guid-3',
          'names' => 'name-1,name-2'
        }
      end

      it 'returns the correct ServiceBrokersListMessage' do
        message = ServiceBrokersListMessage.from_params(params)

        expect(message).to be_a(ServiceBrokersListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.space_guids).to eq(%w[space-guid-1 space-guid-2 space-guid-3])
        expect(message.names).to eq(%w[name-1 name-2])
      end

      it 'converts requested keys to symbols' do
        message = ServiceBrokersListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:space_guids)
        expect(message).to be_requested(:names)
      end
    end

    describe 'order_by' do
      it 'allows name' do
        message = ServiceBrokersListMessage.from_params(order_by: 'name')
        expect(message).to be_valid
      end
    end

    describe 'validation' do
      it 'accepts an empty set' do
        message = ServiceBrokersListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts defined fields' do
        message = ServiceBrokersListMessage.from_params({
                                                          page: 1,
                                                          per_page: 5,
                                                          space_guids: %w[space-guid-1 space-guid2],
                                                          names: %w[name-1 name-2]
                                                        })
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = ServiceBrokersListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'does not accept non-array values for space_guids' do
        message = ServiceBrokersListMessage.from_params({
                                                          space_guids: 'not-an-array'
                                                        })
        expect(message).not_to be_valid
        expect(message.errors_on(:space_guids)).to include('must be an array')
      end

      it 'does not accept non-array values for names' do
        message = ServiceBrokersListMessage.from_params({
                                                          names: 'not-an-array'
                                                        })
        expect(message).not_to be_valid
        expect(message.errors_on(:names)).to include('must be an array')
      end
    end
  end
end
