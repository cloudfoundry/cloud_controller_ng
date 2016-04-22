require 'spec_helper'
require 'messages/packages_list_message'

module VCAP::CloudController
  describe PackagesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states'   => 'state1,state2',
          'types'   => 'type1,type2',
          'page'     => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct PackagesListMessage' do
        message = PackagesListMessage.from_params(params)

        expect(message).to be_a(PackagesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.types).to eq(['type1', 'type2'])
      end

      it 'converts requested keys to symbols' do
        message = PackagesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:states)).to be_truthy
        expect(message.requested?(:types)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          PackagesListMessage.new({
              page:               1,
              per_page:           5,
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = PackagesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = PackagesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      it 'validates types to be an array' do
        message = PackagesListMessage.new(types: 'not array at all')
        expect(message).to be_invalid
        expect(message.errors[:types].length).to eq 1
      end

      it 'validates states to be an array' do
        message = PackagesListMessage.new(states: 'not array at all')
        expect(message).to be_invalid
        expect(message.errors[:states].length).to eq 1
      end
    end
  end
end
