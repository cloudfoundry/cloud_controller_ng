require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppShowMessage do
    it 'does not accept fields not in the set' do
      message = AppShowMessage.new({ foobar: 'pants' })
      expect(message).not_to be_valid
      expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
    end

    it 'does not accept include that is not space' do
      message = AppShowMessage.new({ include: 'space' })
      expect(message).to be_valid
      message = AppShowMessage.new({ include: 'greg\'s buildpack' })
      expect(message).not_to be_valid
    end
  end
end
