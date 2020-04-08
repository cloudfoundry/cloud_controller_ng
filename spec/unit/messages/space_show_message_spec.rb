require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceShowMessage do
    it 'does not accept fields not in the set' do
      message = SpaceShowMessage.from_params({ 'foobar' => 'pants' })
      expect(message).not_to be_valid
      expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
    end

    it 'does not accept include that is not space or org' do
      message = SpaceShowMessage.from_params({ 'include' => 'org' })
      expect(message).to be_valid
      message = SpaceShowMessage.from_params({ 'include' => 'organization' })
      expect(message).to be_valid
      message = SpaceShowMessage.from_params({ 'include' => 'sunny\'s droplet' })
      expect(message).not_to be_valid
    end
  end
end
