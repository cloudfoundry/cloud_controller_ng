require 'spec_helper'
require 'messages/user_update_message'

module VCAP::CloudController
  RSpec.describe UserUpdateMessage do
    describe 'fields' do
      it 'accepts metadata params' do
        message = UserUpdateMessage.new({ 'metadata' => { 'labels' => { 'key' => 'value' }, 'annotations' => { 'key' => 'value' } } })
        expect(message).to be_valid
      end

      it 'does not accept any other params' do
        message = UserUpdateMessage.new({ 'guid' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'guid'")
      end
    end
  end
end
