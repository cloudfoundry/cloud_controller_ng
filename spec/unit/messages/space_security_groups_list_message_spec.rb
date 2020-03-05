require 'spec_helper'
require 'messages/space_security_groups_list_message'

module VCAP::CloudController
  RSpec.describe SpaceSecurityGroupsListMessage do
    describe '.from_params' do
      let(:params) do
        { 'names' => 'sg-name',
          'guids' => 'sg-guid' }
      end

      it 'returns the correct SpaceSecurityGroupsListMessage' do
        message = SpaceSecurityGroupsListMessage.from_params(params)

        expect(message).to be_a(SpaceSecurityGroupsListMessage)
        expect(message.names).to eq(['sg-name'])
        expect(message.guids).to eq(['sg-guid'])
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = SpaceSecurityGroupsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a names param' do
        message = SpaceSecurityGroupsListMessage.from_params({ 'names' => 'test.com,foo.com' })
        expect(message).to be_valid
      end

      it 'accepts a guids param' do
        message = SpaceSecurityGroupsListMessage.from_params({ 'guids' => 'guid1,guid2' })
        expect(message).to be_valid
        expect(message.guids).to eq(%w[guid1 guid2])
      end

      it 'does not accept any other params' do
        message = SpaceSecurityGroupsListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates guids' do
          message = SpaceSecurityGroupsListMessage.from_params({ guids: 'not an array' })
          expect(message).to be_invalid
          expect(message.errors[:guids]).to include('must be an array')
        end
        it 'validates names' do
          message = SpaceSecurityGroupsListMessage.from_params({ guids: 'not an array' })
          expect(message).to be_invalid
          expect(message.errors[:guids]).to include('must be an array')
        end
      end
    end
  end
end
