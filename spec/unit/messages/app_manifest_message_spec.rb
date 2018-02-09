require 'spec_helper'
require 'messages/app_manifests/app_manifest_message'

module VCAP::CloudController
  RSpec.describe AppManifestMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { instances: 3, name: 'foo' } }

      it 'is valid' do
        message = AppManifestMessage.new(params)

        expect(message).to be_valid
      end
    end

    context 'when instances is not an number' do
      let(:params) { { instances: 'silly string thing' } }

      it 'is not valid' do
        message = AppManifestMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('is not a number')
      end
    end

    context 'when instances is not an integer' do
      let(:params) { { instances: 3.5 } }

      it 'is not valid' do
        message = AppManifestMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be an integer')
      end
    end

    context 'when instances is not a positive integer' do
      let(:params) { { instances: -1 } }

      it 'is not valid' do
        message = AppManifestMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be greater than or equal to 0')
      end
    end

    describe '.create_from_http_request' do
      let(:parsed_yaml) { { 'name' => 'blah', 'instances' => 4 } }

      it 'returns the correct AppManifestMessage' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message).to be_a(AppManifestMessage)
        expect(message.instances).to eq(4)
      end

      it 'converts requested keys to symbols' do
        message = AppManifestMessage.create_from_http_request(parsed_yaml)

        expect(message.requested?(:instances)).to be_truthy
      end
    end
  end
end
