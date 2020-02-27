require 'spec_helper'
require 'messages/security_group_list_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupListMessage do
    describe 'validation' do
      it 'accepts an empty set' do
        message = SecurityGroupListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts pagination fields' do
        message = SecurityGroupListMessage.from_params({ page: 1, per_page: 5, order_by: 'updated_at' })
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = SecurityGroupListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
