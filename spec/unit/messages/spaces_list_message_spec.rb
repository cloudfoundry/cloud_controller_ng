require 'spec_helper'
require 'messages/spaces_list_message'

module VCAP::CloudController
  RSpec.describe SpacesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5
        }
      end

      it 'returns the correct SpacesListMessage' do
        message = SpacesListMessage.from_params(params)

        expect(message).to be_a(SpacesListMessage)

        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = SpacesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end
    end
  end
end
