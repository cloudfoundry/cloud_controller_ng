require 'spec_helper'
require 'messages/process_update_message'

module VCAP::CloudController
  RSpec.describe ProcessUpdateMessage do
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

      it 'handles nested health check keys' do
        message = ProcessUpdateMessage.new({ requested: 'thing' })
        expect(message.requested?(:health_check_type)).to be_falsey
        expect(message.requested?(:health_check_timeout)).to be_falsey

        message = ProcessUpdateMessage.new({ health_check: { 'type' => 'type', 'data' => { 'timeout' => 4 } } })
        expect(message.requested?(:health_check_type)).to be_truthy
        expect(message.requested?(:health_check_timeout)).to be_truthy
      end
    end

    describe '#audit_hash' do
      it 'excludes nested health check keys' do
        message = ProcessUpdateMessage.new(
          {
            health_check: { 'type' => 'type', 'data' => { 'timeout' => 4 } }
          })
        expect(message.audit_hash).to eq({ 'health_check' => { 'type' => 'type', 'data' => { 'timeout' => 4 } } })
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

      context 'when health_check type is invalid' do
        let(:params) { { health_check: { type: 'invalid' } } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_type]).to include('must be "port" or "process"')
        end
      end

      context 'when health_check timeout is not an integer' do
        let(:params) do
          {
            health_check: {
              type: 'port',
              data: {
                timeout: 0.2
              }
            }
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_timeout]).to include('must be an integer')
        end
      end

      context 'when health_check timeout is less than zero' do
        let(:params) do
          {
            health_check: {
              type: 'port',
              data: {
                timeout: -7
              }
            }
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_timeout]).to include('must be greater than or equal to 0')
        end
      end

      context 'when health_check timeout not requested' do
        let(:params) do
          {
            health_check: {
              type: 'port'
            }
          }
        end

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).to be_valid
        end
      end

      context 'when ports is not an array' do
        let(:params) do
          {
            ports: 'potato'
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:ports)).to include('must be an array')
        end
      end

      context 'when ports has an array with non-integers' do
        let(:params) do
          {
            ports: ['potato']
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:ports)).to include('must be an array of integers')
        end
      end

      context 'when a port is not in the range 1024-65535' do
        let(:params) do
          {
            ports: [1023]
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:ports)).to include('may only contain ports between 1024 and 65535')
        end
      end

      context 'when there are more than 10 ports' do
        let(:params) do
          {
            ports: (1..11).to_a
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:ports)).to include('may only contain up to 10 ports')
        end
      end

      context 'when ports is nil' do
        let(:params) do
          {
            ports: nil
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:ports)).to include('must be an array')
        end
      end

      context 'when ports is an empty array' do
        let(:params) do
          {
            ports: []
          }
        end

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).to be_valid
        end
      end
    end
  end
end
