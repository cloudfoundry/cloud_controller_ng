require 'spec_helper'
require 'messages/process_update_message'

module VCAP::CloudController
  describe ProcessUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'command' => 'foo' } }

      it 'returns the correct ProcessUpdateMessage' do
        message = ProcessUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(ProcessUpdateMessage)
        expect(message.command).to eq('foo')
      end

      it 'converts requested keys to symbols' do
        message = ProcessUpdateMessage.create_from_http_request(body)

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
        let(:params) { { unexpected: 'foo', extra: 'bar' } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra'")
        end
      end

      context 'when command is not a string' do
        let(:params) { { command: 32.77 } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:command]).to include('must be a string')
        end
      end

      context 'when command is nil' do
        let(:params) { { command: nil } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:command]).to include('must be a string')
        end
      end

      context 'when command is too long' do
        let(:params) { { command: 'a' * 5098 } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:command]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when command is empty' do
        let(:params) { { command: '' } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:command]).to include('must be between 1 and 4096 characters')
        end
      end
    end
  end
end
