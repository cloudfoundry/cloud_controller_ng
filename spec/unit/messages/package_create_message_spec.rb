require 'spec_helper'
require 'messages/package_create_message'

module VCAP::CloudController
  describe PackageCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'type' => 'docker', 'url' => 'the-url' } }

      it 'returns the correct PackageCreateMessage' do
        message = PackageCreateMessage.create_from_http_request('guid', body)

        expect(message).to be_a(PackageCreateMessage)
        expect(message.app_guid).to eq('guid')
        expect(message.type).to eq('docker')
        expect(message.url).to eq('the-url')
      end

      it 'converts requested keys to symbols' do
        message = PackageCreateMessage.create_from_http_request('guid', body)

        expect(message.requested?(:type)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { app_guid: 'guid', type: 'bits', unexpected: 'foo', extra: 'bar' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra'")
        end
      end

      context 'when a type parameter that is not allowed is provided' do
        let(:params) { { app_guid: 'guid', type: 'not-allowed' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be one of \'bits, docker\'')
        end
      end

      context 'type is bits and a url is provided' do
        let(:params) { { app_guid: 'guid', type: 'bits', url: 'a-url' }  }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be blank when type is bits')
        end
      end

      context 'when type is docker' do
        context 'and a url is provided' do
          let(:params) { { app_guid: 'guid', type: 'docker', url: 'foo' }  }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).to be_valid
          end
        end

        context 'and a url is not provided' do
          let(:params) { { app_guid: 'guid', type: 'docker' }  }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include("can't be blank type is docker")
          end
        end
      end

      context 'when guid is invalid' do
        let(:params) { { app_guid: nil, type: 'bits' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:app_guid)).to_not be_empty
        end
      end
    end
  end
end
