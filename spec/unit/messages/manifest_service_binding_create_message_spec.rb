require 'spec_helper'
require 'messages/manifest_service_binding_create_message'

module VCAP::CloudController
  RSpec.describe ManifestServiceBindingCreateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {'services': ['s1', 's2'] }
      }

      it 'returns the correct ManifestServiceBindingCreateMessage' do
        message = ManifestServiceBindingCreateMessage.create_from_http_request(body)

        expect(message).to be_a(ManifestServiceBindingCreateMessage)
        expect(message.services).to match_array(['s1', 's2'])
      end
    end

    describe 'validations' do
      let(:body) {
        {'services': ['s1', 's2'] }
      }

      context 'when all values are correct' do
        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when service instance guid is not an array' do
        let(:body) {
          {'services': 'service' }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instance names')
        end
      end

      context 'when service instance guid is a nested array' do
        let(:body) {
          {'services': [['s1', 's2'], 's3'] }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instance names')
        end
      end

      context 'when unexpected keys are requested' do
        let(:body) {
          {'services': ['s1', 's2'], 'surprise_key': 'surprise' }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'surprise_key'")
        end
      end
    end
  end
end
