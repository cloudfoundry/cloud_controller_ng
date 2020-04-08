require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RoleShowMessage do
    it 'does not accept fields not in the set' do
      message = RoleShowMessage.from_params({ 'foobar' => 'pants' })
      expect(message).not_to be_valid
      expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
    end

    it 'does not accept include that is not user or organization or space' do
      message = RoleShowMessage.from_params({ 'include' => 'user' })
      expect(message).to be_valid
      message = RoleShowMessage.from_params({ 'include' => 'organization' })
      expect(message).to be_valid
      message = RoleShowMessage.from_params({ 'include' => 'space' })
      expect(message).to be_valid
      message = RoleShowMessage.from_params({ 'include' => 'greg\'s buildpack' })
      expect(message).not_to be_valid
    end
  end
end
