require 'spec_helper'
require 'messages/domain_show_message'

module VCAP::CloudController
  RSpec.describe DomainShowMessage do
    describe 'fields' do
      it 'accepts a string guid param' do
        message = DomainShowMessage.new({ 'guid' => 'some-guid' })
        expect(message).to be_valid
      end

      it 'does not accept empty params' do
        message = DomainShowMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include("can't be blank")
      end

      it 'does not accept guid params of incorrect type' do
        message = DomainShowMessage.new({ 'guid' => 123 })
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = DomainShowMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
