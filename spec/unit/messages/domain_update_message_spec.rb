require 'spec_helper'
require 'messages/domain_update_message'

module VCAP::CloudController
  RSpec.describe DomainUpdateMessage do
    describe 'fields' do
      it 'accepts a string guid param' do
        message = DomainUpdateMessage.new({ 'guid' => 'some-guid' })
        expect(message).to be_valid
      end

      it 'accepts metadata params' do
        message = DomainUpdateMessage.new({ 'guid' => 'some-guid', 'metadata' => { 'labels' => { 'key' => 'value' }, 'annotations' => { 'key' => 'value' } } })
        expect(message).to be_valid
      end

      it 'does not accept empty params' do
        message = DomainUpdateMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include("can't be blank")
      end

      it 'does not accept guid params of incorrect type' do
        message = DomainUpdateMessage.new({ 'guid' => 123 })
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = DomainUpdateMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'foobar'")
      end
    end
  end
end
