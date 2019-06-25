require 'spec_helper'
require 'messages/space_delete_unmapped_routes_message'

module VCAP::CloudController
  RSpec.describe SpaceDeleteUnmappedRoutesMessage do
    describe 'fields' do
      it 'accepts unmapped=true param' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'unmapped' => 'true' })
        expect(message).to be_valid
      end

      it 'does not accept unmapped=false param' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'unmapped' => 'false' })
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include("Mass delete not supported for mapped routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
      end

      it 'does not accept empty params' do
        message = SpaceDeleteUnmappedRoutesMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include("can't be blank")
        expect(message.errors[:unmapped]).to include("Mass delete not supported for routes. Use 'unmapped' parameter to delete all unmapped routes.")
      end

      it 'does not accept unmapped params of incorrect type' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'unmapped' => true })
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include('must be a string')
      end

      it 'does not accept any other params' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'foobar'")
      end
    end
  end
end
