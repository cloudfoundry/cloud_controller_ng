require 'spec_helper'
require 'messages/roles_list_message'

module VCAP::CloudController
  RSpec.describe RolesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'updated_at',
        }
      end

      it 'returns the correct RolesListMessage' do
        message = RolesListMessage.from_params(params)

        expect(message).to be_a(RolesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('updated_at')
      end

      it 'converts requested keys to symbols' do
        message = RolesListMessage.from_params(params)

        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
      end

      it 'defaults the order_by parameter if not provided' do
        message = RolesListMessage.from_params({})
        expect(message.order_by).to eq('created_at')
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = RolesListMessage.from_params({
          'page' => 1,
          'per_page'  =>  5,
          'order_by'  =>  'created_at',
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = RolesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = RolesListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'accepts a guids param' do
        message = RolesListMessage.from_params({ guids: %w[guid1 guid2] })
        expect(message).to be_valid
        expect(message.guids).to eq(%w[guid1 guid2])
      end

      it 'does not accept a non-array guids param' do
        message = RolesListMessage.from_params({ guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:guids]).to include('must be an array')
      end

      it 'accepts a organization_guids param' do
        message = RolesListMessage.from_params({ organization_guids: %w[organization_guid1 organization_guid2] })
        expect(message).to be_valid
        expect(message.organization_guids).to eq(%w[organization_guid1 organization_guid2])
      end

      it 'does not accept a non-array organization_guids param' do
        message = RolesListMessage.from_params({ organization_guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:organization_guids]).to include('must be an array')
      end

      it 'accepts a space_guids param' do
        message = RolesListMessage.from_params({ space_guids: %w[space_guid1 space_guid2] })
        expect(message).to be_valid
        expect(message.space_guids).to eq(%w[space_guid1 space_guid2])
      end

      it 'does not accept a non-array space_guids param' do
        message = RolesListMessage.from_params({ space_guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:space_guids]).to include('must be an array')
      end

      it 'accepts a user_guids param' do
        message = RolesListMessage.from_params({ user_guids: %w[user_guid1 user_guid2] })
        expect(message).to be_valid
        expect(message.user_guids).to eq(%w[user_guid1 user_guid2])
      end

      it 'does not accept a non-array user_guids param' do
        message = RolesListMessage.from_params({ user_guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:user_guids]).to include('must be an array')
      end

      it 'accepts a types param' do
        message = RolesListMessage.from_params({ types: %w[type1 type2] })
        expect(message).to be_valid
        expect(message.types).to eq(%w[type1 type2])
      end

      it 'does not accept a non-array types param' do
        message = RolesListMessage.from_params({ types: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:types]).to include('must be an array')
      end

      it 'reject an invalid order_by field' do
        message = RolesListMessage.from_params({
          'order_by' =>  'fail!',
        })
        expect(message).not_to be_valid
      end
    end
  end
end
