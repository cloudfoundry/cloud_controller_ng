require 'spec_helper'
require 'messages/base_message'

module VCAP::CloudController
  describe BaseMessage do
    describe '#requested?' do
      it 'returns true if the key was requested, false otherwise' do
        message = BaseMessage.new({ requested: 'thing' })

        expect(message.requested?(:requested)).to be_truthy
        expect(message.requested?(:notrequested)).to be_falsey
      end
    end

    describe 'additional keys validation' do
      class AdditionalKeysMessage < VCAP::CloudController::BaseMessage
        validates_with NoAdditionalKeysValidator

        attr_accessor :allowed

        def allowed_keys
          [:allowed]
        end
      end

      it 'is valid with an allowed message' do
        message = AdditionalKeysMessage.new({ allowed: 'something' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed keys in the message' do
        message = AdditionalKeysMessage.new({ notallowed: 'something', extra: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'notallowed', 'extra'")
      end
    end

    describe 'guid validation' do
      class GuidMessage < VCAP::CloudController::BaseMessage
        attr_accessor :guid
        validates :guid, guid: true

        def allowed_keys
          [:guid]
        end
      end

      context 'when guid is not a string' do
        let(:params) { { guid: 4 } }

        it 'is not valid' do
          message = GuidMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when guid is nil' do
        let(:params) { { guid: 4 } }

        it 'is not valid' do
          message = GuidMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when guid is too long' do
        let(:params) { { guid: 'a' * 201 } }

        it 'is not valid' do
          message = GuidMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 200 characters')
        end
      end

      context 'when guid is empty' do
        let(:params) { { guid: '' } }

        it 'is not valid' do
          message = GuidMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 200 characters')
        end
      end
    end
  end
end
