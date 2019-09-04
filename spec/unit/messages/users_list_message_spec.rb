require 'spec_helper'
require 'messages/users_list_message'

module VCAP::CloudController
  RSpec.describe UsersListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'guids' => 'user1-guid,user2-guid'
        }
      end

      it 'returns the correct UsersListMessage' do
        message = UsersListMessage.from_params(params)

        expect(message).to be_a(UsersListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.guids).to eq(%w[user1-guid user2-guid])
      end

      it 'converts requested keys to symbols' do
        message = UsersListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          page: 1,
          per_page: 5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = []
        expect(UsersListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = UsersListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a guids param' do
        message = UsersListMessage.from_params({ guids: %w[guid1 guid2] })
        expect(message).to be_valid
        expect(message.guids).to eq(%w[guid1 guid2])
      end

      it 'does not accept a non-array guids param' do
        message = UsersListMessage.from_params({ guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:guids]).to include('must be an array')
      end

      it 'does not accept a field not in this set' do
        message = UsersListMessage.from_params({ foobar: 'pants' })

        expect(message).to be_invalid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
