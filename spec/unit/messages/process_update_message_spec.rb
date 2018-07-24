require 'spec_helper'
require 'messages/process_update_message'

module VCAP::CloudController
  RSpec.describe ProcessUpdateMessage do
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

        message = ProcessUpdateMessage.new({ health_check: { type: 'type', data: { timeout: 4, invocation_timeout: 7 } } })
        expect(message.requested?(:health_check_type)).to be_truthy
        expect(message.requested?(:health_check_timeout)).to be_truthy
        expect(message.requested?(:health_check_invocation_timeout)).to be_truthy
      end
    end

    describe '#audit_hash' do
      it 'excludes nested health check keys' do
        message = ProcessUpdateMessage.new(
          {
            health_check: { type: 'type', data: { timeout: 4, endpoint: 'something', invocation_timeout: 7 } }
          })
        expect(message.audit_hash).to eq({ 'health_check' => { 'type' => 'type', 'data' => { 'timeout' => 4, 'endpoint' => 'something', 'invocation_timeout' => 7 } } })
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo', extra: 'bar', ports: [8181] } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra', 'ports'")
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

        it 'it is valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).to be_valid
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

      context 'when health_check type is http' do
        let(:params) { { health_check: { type: 'http' } } }

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).to be_valid
        end
      end

      context 'when health_check type is process' do
        let(:params) { { health_check: { type: 'process' } } }

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).to be_valid
        end
      end

      context 'when health_check type is port' do
        let(:params) { { health_check: { type: 'port' } } }

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).to be_valid
        end
      end

      context 'when health_check type is invalid' do
        let(:params) { { health_check: { type: 'invalid' } } }

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_type]).to include('must be "port", "process", or "http"')
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

      context 'when health_check timeout is less than one' do
        let(:params) do
          {
            health_check: {
              type: 'port',
              data: {
                timeout: 0
              }
            }
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_timeout]).to include('must be greater than or equal to 1')
        end
      end

      context 'when health_check invocation timeout is not an integer' do
        let(:params) do
          {
            health_check: {
              type: 'http',
              data: {
                invocation_timeout: 0.2
              }
            }
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_invocation_timeout]).to include('must be an integer')
        end
      end

      context 'when health_check invocation timeout is less than one' do
        let(:params) do
          {
            health_check: {
              type: 'http',
              data: {
                invocation_timeout: 0
              }
            }
          }
        end

        it 'is not valid' do
          message = ProcessUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:health_check_invocation_timeout]).to include('must be greater than or equal to 1')
        end
      end

      context 'when health_check timeout and endpoint are not requested' do
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

      context 'when health_check endpoint is requested' do
        let(:endpoint) { '/healthcheck' }
        let(:params) do
          {
            health_check: {
              type: 'port',
              data: {
                endpoint: endpoint.to_s
              }
            }
          }
        end

        it 'is valid' do
          message = ProcessUpdateMessage.new(params)
          expect(message).to be_valid
        end

        context 'when endpoint is not a valid URI path' do
          let(:endpoint) { "some words that aren't a uri" }

          it 'is not valid' do
            message = ProcessUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors[:health_check_endpoint]).to include('must be a valid URI path')
          end
        end
      end
    end
  end
end
