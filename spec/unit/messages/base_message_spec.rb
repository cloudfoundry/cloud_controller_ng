require 'spec_helper'
require 'messages/base_message'

module VCAP::CloudController
  describe BaseMessage do
    describe '#requested?' do
      it 'returns true if the key was requested, false otherwise' do
        FakeClass = Class.new(BaseMessage) do
          def allowed_keys
            []
          end
        end

        message = FakeClass.new({ requested: 'thing' })

        expect(message.requested?(:requested)).to be_truthy
        expect(message.requested?(:notrequested)).to be_falsey
      end
    end

    describe '#audit_hash' do
      class AuditMessage < BaseMessage
        attr_accessor :field1, :field2

        def allowed_keys
          [:field1, :field2]
        end
      end

      it 'returns only requested keys in a json object' do
        message  = AuditMessage.new({ field1: 'value1' })
        response = message.audit_hash
        expect(response).to eq({ 'field1' => 'value1' })
      end

      it 'recursively includes keys' do
        message  = AuditMessage.new({ field1: 'value1', field2: { 'subfield' => 'subfield' } })
        response = message.audit_hash
        expect(response).to eq({ 'field1' => 'value1', 'field2' => { 'subfield' => 'subfield' } })
      end
    end

    describe 'additional keys validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          validates_with VCAP::CloudController::BaseMessage::NoAdditionalKeysValidator

          def allowed_keys
            [:allowed]
          end

          def allowed=(_)
          end
        end
      end

      it 'is valid with an allowed message' do
        message = fake_class.new({ allowed: 'something' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed keys in the message' do
        message = fake_class.new({ notallowed: 'something', extra: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'notallowed', 'extra'")
      end
    end
  end
end
