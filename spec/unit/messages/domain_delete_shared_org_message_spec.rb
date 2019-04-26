require 'spec_helper'
require 'messages/domain_delete_shared_org_message'

module VCAP::CloudController
  RSpec.describe DomainDeleteSharedOrgMessage do
    describe 'fields' do
      it 'accepts string guid and domain_guid params' do
        message = DomainDeleteSharedOrgMessage.new({ 'guid' => 'some-domain-guid', 'org_guid' => 'some-org-guid' })
        expect(message).to be_valid
      end

      it 'does not accept empty params' do
        message = DomainDeleteSharedOrgMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include("can't be blank")
      end

      it 'does not accept params without org_guid' do
        message = DomainDeleteSharedOrgMessage.new({ 'guid' => 'some-domain-guid' })
        expect(message).not_to be_valid
        expect(message.errors[:org_guid]).to include("can't be blank")
      end

      it 'does not accept guid params of incorrect type' do
        message = DomainDeleteSharedOrgMessage.new({ 'guid' => 123, 'org_guid' => 456 })
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include('must be a string')
        expect(message.errors[:org_guid]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = DomainDeleteSharedOrgMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'foobar'")
      end
    end
  end
end
