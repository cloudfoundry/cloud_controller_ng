require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessShowMessage do
    it 'does not accept fields not in the set' do
      message = ProcessShowMessage.from_params({ 'foo' => 'bar' })
      expect(message).not_to be_valid
      expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foo'")
    end

    it 'does not accept embed other than process_instances' do
      message = ProcessShowMessage.from_params({ 'embed' => 'process_instances' })
      expect(message).to be_valid
      message = ProcessShowMessage.from_params({ 'embed' => 'stats' })
      expect(message).not_to be_valid
    end
  end
end
