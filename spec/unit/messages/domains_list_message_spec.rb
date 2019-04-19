require 'spec_helper'
require 'messages/domains_list_message'

module VCAP::CloudController
  RSpec.describe DomainsListMessage do
    describe '.from_params' do
      let(:params) do
        {}
      end

      it 'returns the correct DomainsListMessage' do
        message = DomainsListMessage.from_params(params)

        expect(message).to be_a(DomainsListMessage)
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = DomainsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a names param' do
        message = DomainsListMessage.from_params({ 'names' => 'test.com,foo.com' })
        expect(message).to be_valid
      end

      it 'does not accept any other params' do
        message = DomainsListMessage.from_params({ 'foobar' => 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
