require 'spec_helper'
require 'messages/route_destination_update_message'

module VCAP::CloudController
  RSpec.describe RouteDestinationUpdateMessage do
    describe 'protocol' do
      it 'accepts a tcp protocol param' do
        message = RouteDestinationUpdateMessage.new({ 'protocol' => 'tcp' })
        expect(message).to be_valid
      end

      it 'accepts an http1 protocol param' do
        message = RouteDestinationUpdateMessage.new({ 'protocol' => 'http1' })
        expect(message).to be_valid
      end

      it 'accepts an http2 protocol param' do
        message = RouteDestinationUpdateMessage.new({ 'protocol' => 'http2' })
        expect(message).to be_valid
      end

      it 'accepts empty params' do
        message = RouteDestinationUpdateMessage.new({})
        expect(message).to be_valid
      end

      it 'does not accept any other strings' do
        message = RouteDestinationUpdateMessage.new({ 'protocol' => 'my-cool-protocol' })
        expect(message).not_to be_valid
        expect(message.errors[:destination]).to include("protocol must be 'http1', 'http2' or 'tcp'.")
      end

      it 'does not accept protocol params of incorrect type' do
        message = RouteDestinationUpdateMessage.new({ 'protocol' => 123 })
        expect(message).not_to be_valid
        expect(message.errors[:destination]).to include("protocol must be 'http1', 'http2' or 'tcp'.")
      end

      it 'does not accept any other params' do
        message = RouteDestinationUpdateMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'foobar'")
      end
    end
  end
end
