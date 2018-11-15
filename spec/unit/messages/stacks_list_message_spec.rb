require 'spec_helper'
require 'messages/stacks_list_message'

module VCAP::CloudController
  RSpec.describe StacksListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct StacksListMessage' do
        message = StacksListMessage.from_params(params)

        expect(message).to be_a(StacksListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end
    end
  end
end
