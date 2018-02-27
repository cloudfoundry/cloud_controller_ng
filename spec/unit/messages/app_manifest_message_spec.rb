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
      context 'when memory unit is not part of expected set of values' do
        let(:params) { { memory: '200INVALID' } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
        end
      end
    end

    describe 'disk_quota' do
      context 'when disk_quota unit is not part of expected set of values' do
        let(:params) { { disk_quota: '200INVALID' } }

        it 'is not valid' do
          message = AppManifestMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Disk Quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')
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

    describe '#process_scale_message' do
      let(:parsed_yaml) { { 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 } }

      it 'returns a ProcessScaleMessage containing mapped attributes' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.process_scale_message.instances).to eq(5)
        expect(message.process_scale_message.memory_in_mb).to eq(204800)
        expect(message.process_scale_message.disk_in_mb).to eq(1024000)
      end

      context 'when attributes are not requested in the manifest' do
        let(:parsed_yaml) { {} }

        it 'does not forward missing attributes to the ProcessScaleMessage' do
          message = AppManifestMessage.create_from_http_request(parsed_yaml)

          expect(message.process_scale_message.requested?(:instances)).to be false
          expect(message.process_scale_message.requested?(:memory_in_mb)).to be false
          expect(message.process_scale_message.requested?(:disk_in_mb)).to be false
        end
      end
    end
  end
end
