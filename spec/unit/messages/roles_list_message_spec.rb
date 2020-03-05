require 'spec_helper'
require 'messages/roles_list_message'

module VCAP::CloudController
  RSpec.describe RolesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'updated_at',
          'types' => 'space_auditor',
          'guids' => 'my-role-guid',
          'user_guids' => 'my-user-guid',
          'space_guids' => 'my-space-guid',
          'organization_guids' => 'my-organization-guid',
          'include' => 'user,organization,space',
        }
      end

      it 'returns the correct RolesListMessage' do
        message = RolesListMessage.from_params(params)

        expect(message).to be_a(RolesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('updated_at')
        expect(message.guids).to eq(['my-role-guid'])
        expect(message.user_guids).to eq(['my-user-guid'])
        expect(message.space_guids).to eq(['my-space-guid'])
        expect(message.organization_guids).to eq(['my-organization-guid'])
        expect(message.include).to eq(%w(user organization space))
      end

      it 'converts requested keys to symbols' do
        message = RolesListMessage.from_params(params)

        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
        expect(message.requested?(:guids)).to be true
        expect(message.requested?(:user_guids)).to be true
        expect(message.requested?(:space_guids)).to be true
        expect(message.requested?(:organization_guids)).to be true
        expect(message.requested?(:include)).to be true
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
          'per_page' => 5,
          'order_by' => 'created_at',
          'types' => 'space_auditor',
          'guids' => 'my-role-guid',
          'user_guids' => 'my-user-guid',
          'space_guids' => 'my-space-guid',
          'organization_guids' => 'my-organization-guid',
          'include' => 'user,organization,space',
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
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
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

      it 'accepts an include param' do
        message = RolesListMessage.from_params({ include: ['user'] })
        expect(message).to be_valid
        expect(message.include).to eq(['user'])
      end

      it 'does not accept an include param that is invalid' do
        message = RolesListMessage.from_params({ include: ['garbage'] })
        expect(message).to be_invalid
        expect(message.errors[:base]).to contain_exactly(include("Invalid included resource: 'garbage'"))
      end

      it 'reject an invalid order_by field' do
        message = RolesListMessage.from_params({
          'order_by' => 'fail!',
        })
        expect(message).not_to be_valid
      end
    end
  end
end
