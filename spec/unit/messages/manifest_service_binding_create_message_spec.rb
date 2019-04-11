require 'spec_helper'
require 'messages/manifest_service_binding_create_message'

module VCAP::CloudController
  RSpec.describe ManifestServiceBindingCreateMessage do
    describe 'validations' do
      let(:body) {
        { 'services' => ['s1', 's2'] }
      }

      context 'when all values are correct' do
        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when services are an array of hashes' do
        let(:body) do
          { services:
            [
              {
                'name' => 'has_parameters',
                'parameters' => {
                  'foo' => 'bar'
                }
              },
              {
                name: 'no_parameters'
              }
            ]
          }
        end
        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when services are an array of hashes with out the name parameter' do
        let(:body) do
          { services:
            [
              {
                'parameters' => {
                  'foo' => 'bar'
                }
              },
            ]
          }
        end
        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).not_to be_valid
        end
      end

      context 'when services are an array of hashes with invalid keys' do
        let(:body) do
          { services:
            [
              {
                'name' => 'has_parameters',
                'invalid' => {
                  'foo' => 'bar'
                }
              }
            ]
          }
        end
        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).not_to be_valid
        end
      end

      context 'when service instances is not an array' do
        let(:body) {
          { 'services': 'service' }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
        end
      end

      context 'when service instances is a nested array' do
        let(:body) {
          { 'services': [['s1', 's2'], 's3'] }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
        end
      end

      context 'when unexpected keys are requested' do
        let(:body) {
          { 'services': ['s1', 's2'], 'surprise_key': 'surprise' }
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
