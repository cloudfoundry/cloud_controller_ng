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
        expect(message.errors[:base]).to include("Mass delete not supported for mapped routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
      end

      it 'does not accept empty params' do
        message = SpaceDeleteUnmappedRoutesMessage.new({})
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include("can't be blank")
        expect(message.errors[:base]).to include("Mass delete not supported for routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
      end

      it 'does not accept specified-but-unset unmapped param' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'unmapped' => nil })
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include('must be a boolean')
      end

      it 'does not accept unmapped param set to incorrect type' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'unmapped' => 'some-string' })
        expect(message).not_to be_valid
        expect(message.errors[:unmapped]).to include('must be a boolean')
      end

      it 'does not accept any other params' do
        message = SpaceDeleteUnmappedRoutesMessage.new({ 'foobar' => 'pants' })
        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'foobar'")
      end
    end
  end
end
