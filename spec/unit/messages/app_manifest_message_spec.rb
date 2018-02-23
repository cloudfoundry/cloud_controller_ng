require 'spec_helper'
require 'messages/app_manifests/app_manifest_message'

module VCAP::CloudController
  RSpec.describe AppManifestMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { instances: 3, memory: '2G', name: 'foo' } }

      it 'is valid' do
        message = AppManifestMessage.new(params)

        expect(message).to be_valid
      end
    end

    describe 'memory' do
      context 'when memory does not have a unit' do
        let(:params) { { memory: '5' } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
        end
      end

      context 'when memory is not part of expected set of values' do
        let(:params) { { memory: '200INVALID' } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
        end
      end
    end

    describe 'instances' do
      context 'when instances is not an number' do
        let(:params) { { instances: 'silly string thing' } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Instances is not a number')
        end
      end

      context 'when instances is not an integer' do
        let(:params) { { instances: 3.5 } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Instances must be an integer')
        end
      end

      context 'when instances is not a positive integer' do
        let(:params) { { instances: -1 } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Instances must be greater than or equal to 0')
        end
      end
    end

    describe '.create_from_http_request' do
      let(:parsed_yaml) { { 'name' => 'blah', 'instances' => 4, 'memory' => '200GB' } }

      it 'returns the correct AppManifestMessage' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message).to be_a(AppManifestMessage)
        expect(message.instances).to eq(4)
        expect(message.memory).to eq('200GB')
      end

      it 'converts requested keys to symbols' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.requested?(:instances)).to be_truthy
        expect(message.requested?(:memory)).to be_truthy
      end
    end
  end
end
