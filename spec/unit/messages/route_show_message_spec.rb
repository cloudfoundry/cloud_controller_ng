require 'spec_helper'
require 'messages/route_show_message'

module VCAP::CloudController
  RSpec.describe RouteShowMessage do
    describe 'fields' do
      it 'accepts a string guid param' do
        message = RouteShowMessage.new({ 'guid' => 'some-guid' })
        expect(message).to be_valid
      end

      it 'does not accept empty params' do
        message = RouteShowMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include("can't be blank")
      end

      it 'does not accept guid params of incorrect type' do
        message = RouteShowMessage.new({ 'guid' => 123 })
        expect(message).not_to be_valid
        expect(message.errors[:guid]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = RouteShowMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
