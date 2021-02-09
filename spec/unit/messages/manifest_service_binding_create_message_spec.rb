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
                },
                'binding_name' => 'my-binding-name'
              },
              {
                name: 'no_parameters'
              },
              'other-instance-name'
            ]
          }
        end

        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).to be_valid
        end
      end

      context 'when services are an array of hashes without the name parameter' do
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
        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)
          expect(message).not_to be_valid
        end
      end

      context 'when services are an array of hashes with invalid parameter value' do
        let(:body) do
          { services:
            [
              {
                'name' => 'has_parameters',
                'parameters' => 'foo'
              }
            ]
          }
        end

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
        end
      end

      context 'when services are an array of hashes with invalid binding-name value' do
        let(:body) do
          { services:
            [
              {
                'name' => 'has_parameters',
                'binding_name' => 123
              }
            ]
          }
        end

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
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
          { services: 'service' }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
        end
      end

      context 'when service instances is a nested array' do
        let(:body) {
          { services: [['s1', 's2'], 's3'] }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:services]).to include('must be a list of service instances')
        end
      end

      context 'when unexpected keys are requested' do
        let(:body) {
          { services: ['s1', 's2'], surprise_key: 'surprise' }
        }

        it 'is not valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'surprise_key'")
        end
      end
    end

    describe 'manifest_service_bindings' do
      context 'when all values are correct' do
        let(:params) { { foo: 'bar' } }
        let(:body) do
          { services:
            [
              {
                'name' => 'instance-name-1',
                'parameters' => params,
                'binding_name' => 'my-binding-name'
              },
              'instance-name-2',
              {
                'name' => 'instance-name-3',
              },
            ]
          }
        end

        it 'is valid' do
          message = ManifestServiceBindingCreateMessage.new(body)

          result = message.manifest_service_bindings

          expect(result[0].name).to eq('instance-name-1')
          expect(result[0].parameters).to eq(params)
          expect(result[0].binding_name).to eq('my-binding-name')

          expect(result[1].name).to eq('instance-name-2')
          expect(result[1].parameters).to eq({})
          expect(result[1].binding_name).to be_nil

          expect(result[2].name).to eq('instance-name-3')
          expect(result[2].parameters).to be_nil
          expect(result[2].binding_name).to be_nil
        end
      end
    end
  end
end
