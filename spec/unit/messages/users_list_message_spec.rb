require 'spec_helper'
require 'messages/users_list_message'

module VCAP::CloudController
  RSpec.describe UsersListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'guids' => 'user1-guid,user2-guid',
          'usernames' => 'user1-name,user2-name',
          'origins' => 'user1-origin,user2-origin',
        }
      end

      it 'returns the correct UsersListMessage' do
        message = UsersListMessage.from_params(params)

        expect(message).to be_a(UsersListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.guids).to eq(%w[user1-guid user2-guid])
        expect(message.usernames).to eq(%w[user1-name user2-name])
        expect(message.origins).to eq(%w[user1-origin user2-origin])
      end

      it 'converts requested keys to symbols' do
        message = UsersListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:usernames)).to be_truthy
        expect(message.requested?(:origins)).to be_truthy
      end

      context 'guids, usernames, origins are nil' do
        let(:params) do
          {
            guids: nil,
            usernames: nil,
            origins: nil,
          }
        end

        it 'is valid' do
          message = UsersListMessage.from_params(params)
          expect(message).to be_valid
        end

        context 'guids, usernames, origins must be arrays' do
          let(:params) do
            {
              guids: 'a',
              usernames: { 'not' => 'an array' },
              origins: 3.14159,
            }
          end

          it 'is invalid' do
            message = UsersListMessage.from_params(params)
            expect(message).to be_invalid
            expect(message.errors.details[:guids].first[:error]).to eq('must be an array')
            expect(message.errors.details[:usernames].first[:error]).to eq('must be an array')
            expect(message.errors.details[:origins].first[:error]).to eq('must be an array')
          end
        end
      end
    end

    describe 'origin_requires_username' do
      it 'accepts usernames and origins' do
        message = UsersListMessage.from_params({ usernames: ['bob'], origins: ['uaa'] })
        expect(message).to be_valid
      end
      it 'accepts no usernames no origins' do
        message = UsersListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts usernames without origins' do
        message = UsersListMessage.from_params({ usernames: ['bob'] })
        expect(message).to be_valid
      end

      it 'does NOT accept origins without usernames' do
        message = UsersListMessage.from_params({ origins: ['uaa'] })
        expect(message).to be_invalid
        expect(message.errors[:origins]).to include('filter cannot be provided without usernames filter.')
      end
    end
  end
end
