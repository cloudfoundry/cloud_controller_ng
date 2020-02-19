require 'spec_helper'
require 'messages/sidecars_list_message'

module VCAP::CloudController
  RSpec.describe SidecarsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
        }
      end

      it 'returns the correct SidecarsListMessage' do
        message = SidecarsListMessage.from_params(params)

        expect(message).to be_a(SidecarsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = SidecarsListMessage.from_params(params)

        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = SidecarsListMessage.from_params({
          page:      1,
          per_page:  5,
          order_by:  'created_at',
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = SidecarsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = SidecarsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'reject an invalid order_by field' do
        message = SidecarsListMessage.from_params({
          order_by:  'fail!',
        })
        expect(message).not_to be_valid
      end
    end
  end
end
