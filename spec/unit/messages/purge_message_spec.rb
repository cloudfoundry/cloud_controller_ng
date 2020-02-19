require 'spec_helper'
require 'messages/purge_message'

module VCAP::CloudController
  RSpec.describe PurgeMessage do
    describe '.from_params' do
      it 'accepts an empty value' do
        message = PurgeMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = PurgeMessage.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'accepts `true`' do
        message = PurgeMessage.from_params({ purge: 'true' }.with_indifferent_access)
        expect(message).to be_valid
      end

      it 'accepts `false`' do
        message = PurgeMessage.from_params({ purge: 'false' }.with_indifferent_access)
        expect(message).to be_valid
      end

      it 'does not accept other values' do
        message = PurgeMessage.from_params({ purge: 'nope' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:purge]).to include("only accepts values 'true' or 'false'")
      end
    end

    describe '.purge?' do
      it 'can be true' do
        message = PurgeMessage.from_params({ purge: 'true' }.with_indifferent_access)
        expect(message.purge?).to be(true)
      end

      it 'can be false' do
        message = PurgeMessage.from_params({ purge: 'false' }.with_indifferent_access)
        expect(message.purge?).to be(false)
      end

      it 'is false by default' do
        message = PurgeMessage.from_params({}.with_indifferent_access)
        expect(message.purge?).to be(false)
      end
    end
  end
end
