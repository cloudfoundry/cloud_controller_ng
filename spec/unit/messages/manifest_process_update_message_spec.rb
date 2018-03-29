require 'spec_helper'
require 'messages/manifest_process_update_message'

module VCAP::CloudController
  RSpec.describe ManifestProcessUpdateMessage do
    let(:message) { ManifestProcessUpdateMessage.create_from_http_request(body) }
    let(:body) { {} }

    describe '.create_from_http_request' do
      let(:body) do
        {
          'command' => 'rspec spec',
          'health_check_type' => 'http',
          'health_check_http_endpoint' => '/health',
          'timeout' => 42,
        }
      end

      it 'returns the correct ManifestProcessUpdateMessage' do
        expect(message).to be_a(ManifestProcessUpdateMessage)
        expect(message.command).to eq('rspec spec')
        expect(message.health_check_type).to eq('http')
        expect(message.health_check_endpoint).to eq('/health')
        expect(message.health_check_timeout).to eq(42)
      end
    end

    describe 'validations' do
      let(:message) { ManifestProcessUpdateMessage.new(params) }

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo', extra: 'bar', ports: [8181] } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra', 'ports'")
        end
      end

      context 'when no keys are requested' do
        let(:params) { {} }

        it 'is valid' do
          expect(message).to be_valid
        end
      end

      describe 'command' do
        context 'when command is not a string' do
          let(:params) { { command: 32.77 } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:command]).to include('must be a string')
          end
        end

        context 'when command is nil' do
          let(:params) { { command: nil } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:command]).to include('must be a string')
          end
        end

        context 'when command is too long' do
          let(:params) { { command: 'a' * 5098 } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:command]).to include('must be between 1 and 4096 characters')
          end
        end

        context 'when command is empty' do
          let(:params) { { command: '' } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:command]).to include('must be between 1 and 4096 characters')
          end
        end
      end

      describe 'health_check_type' do
        context 'when health_check type is http' do
          let(:params) { { health_check_type: 'http' } }

          it 'is valid' do
            expect(message).to be_valid
          end
        end

        context 'when health_check type is process' do
          let(:params) { { health_check_type: 'process' } }

          it 'is valid' do
            expect(message).to be_valid
          end
        end

        context 'when health_check type is port' do
          let(:params) { { health_check_type: 'port' } }

          it 'is valid' do
            expect(message).to be_valid
          end
        end

        context 'when health_check type is invalid' do
          let(:params) { { health_check_type: 'metal' } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:health_check_type]).to include('must be "port", "process", or "http"')
          end
        end
      end

      describe 'health_check_http_endpoint' do
        context 'when health_check_http_endpoint is not a valid URI path' do
          let(:params) { { health_check_http_endpoint: 'hello there' } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:health_check_http_endpoint]).to include('must be a valid URI path')
          end
        end
      end

      describe 'timeout' do
        context 'when timeout is not an number' do
          let(:params) { { timeout: 'hello there' } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:timeout]).to include('is not a number')
          end
        end

        context 'when timeout is not an integer' do
          let(:params) { { timeout: 1.1 } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:timeout]).to include('must be an integer')
          end
        end

        context 'when timeout is less than one' do
          let(:params) { { timeout: 0 } }

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors[:timeout]).to include('must be greater than or equal to 1')
          end
        end
      end
    end

    describe '#requested?' do
      attribute_mappings = {
        'timeout' => :health_check_timeout,
        'health_check_http_endpoint' => :health_check_endpoint,
        'health_check_type' => :health_check_type,
        'command' => :command,
      }

      attribute_mappings.each do |manifest_attribute, message_attribute|
        context "when #{manifest_attribute} is requested" do
          let(:body) { { manifest_attribute => 'value' } }

          it "returns true for #{message_attribute}" do
            expect(message.requested?(message_attribute)).to be true
          end
        end

        context "when #{manifest_attribute} is not requested" do
          let(:body) { {} }

          it "returns false for #{message_attribute}" do
            expect(message.requested?(message_attribute)).to be false
          end
        end
      end
    end
  end
end
