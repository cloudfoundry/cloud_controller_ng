require 'spec_helper'
require 'messages/process_update_message'

module VCAP::CloudController
  describe ProcessUpdateMessage do
    let(:guid) { 'the-guid' }

    describe '.create_from_http_request' do
      let(:body) { { 'command' => 'foo' } }

      it 'returns the correct ProcessUpdateMessage' do
        message = ProcessUpdateMessage.create_from_http_request(guid, body)

        expect(message).to be_a(ProcessUpdateMessage)
        expect(message.guid).to eq(guid)
        expect(message.command).to eq('foo')
      end

      it 'converts requested keys to symbols' do
        message = ProcessUpdateMessage.create_from_http_request(guid, body)

        expect(message.requested?(:command)).to be_truthy
      end
    end

    describe '#requested?' do
      it 'returns true if the key was requested, false otherwise' do
        message = ProcessUpdateMessage.new({ requested: 'thing' })

        expect(message.requested?(:requested)).to be_truthy
        expect(message.requested?(:notrequested)).to be_falsey
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { guid: guid, unexpected: 'foo', extra: 'bar' } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra'")
        end
      end

      context 'when command is not a string' do
        let(:params) { { guid: guid, command: 32.77 } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when command is nil' do
        let(:params) { { guid: guid, command: nil } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when command is too long' do
        let(:params) { { guid: guid, command: 'a' * 5098 } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when command is empty' do
        let(:params) { { guid: guid, command: '' } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when guid is invalid' do
        let(:params) { { guid: nil } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:guid)).to_not be_empty
        end
      end
    end
  end
end
