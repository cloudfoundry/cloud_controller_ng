require 'spec_helper'
require 'messages/package_create_message'

module VCAP::CloudController
  RSpec.describe PackageCreateMessage do
    describe 'validations' do
      let(:relationships) { { app: { data: { guid: 'some-guid' } } } }

      context 'when unexpected keys are requested' do
        let(:params) { { relationships: relationships, type: 'bits', unexpected: 'foo', extra: 'bar' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra'")
        end
      end

      context 'when a type parameter that is not allowed is provided' do
        let(:params) { { relationships: relationships, type: 'not-allowed' } }

        it 'is not valid' do
          message = PackageCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:type]).to include('must be one of \'bits, docker\'')
        end
      end

      context 'relationships' do
        let(:params) { { relationships: relationships, type: 'bits' } }

        context 'when guid is invalid' do
          let(:relationships) { { app: { data: { guid: nil } } } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include('App guid must be a string')
          end
        end

        context 'when there are unexpected keys' do
          let(:relationships) { { app: { guid: 'some-guid' }, potato: 'fried' } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("Unknown field(s): 'potato'")
          end
        end

        context 'when the relationships field is nil' do
          let(:relationships) { nil }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
          end
        end

        context 'when the relationships field is non-hash, non-nil garbage' do
          let(:relationships) { 'gorniplatz' }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
          end
        end
      end

      context 'bits' do
        context 'when a data parameter is provided for a bits package and it is not empty' do
          let(:params) { { relationships: relationships, type: 'bits', data: { foobar: 'foobaz' } } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include('Data must be empty if provided for bits packages')
          end
        end

        context 'when a data parameter is not provided for a bits package' do
          let(:params) { { relationships: relationships, type: 'bits' } }

          it 'is valid' do
            message = PackageCreateMessage.new(params)
            expect(message).to be_valid
          end
        end
      end

      context 'when a docker type is requested' do
        context 'when data is not provided' do
          let(:params) { { relationships: relationships, type: 'docker' } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image required')
          end
        end

        context 'when an image is not provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { store_image: false, credentials: {} } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image required')
          end
        end

        context 'when a non-string image is provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { image: 5, store_image: false, credentials: {} } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image must be a string')
          end
        end

        context 'when unexpected data keys are provided' do
          let(:params) { { relationships: relationships, type: 'docker', data: { image: 'path/to/image/', birthday: 'party' } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include("Unknown field(s): 'birthday'")
          end
        end
      end

      context 'when the message includes metadata' do
        let(:params) { { relationships: relationships, type: 'bits' } }
        let(:metadata) do
          {

            'metadata' => {
              'labels' => {
                'potatoes' => 'packagedTots'
              }
            }
          }
        end
        let(:all_params) { params.merge(metadata) }

        it 'is valid and correctly parses the labels' do
          message = PackageCreateMessage.new(all_params)
          expect(message).to be_valid
          expect(message.labels).to include(potatoes: 'packagedTots')
        end
      end
    end

    describe '#audit_hash' do
      let(:app) { AppModel.make }
      let(:relationships) { { app: { data: { guid: app.guid } } } }

      context 'when a data field is present' do
        let(:image) { 'registry/image:latest' }
        let(:docker_username) { 'anakin' }
        let(:docker_password) { 'n1k4n4' }
        let(:message) do
          data = {
            type: 'docker',
            relationships: relationships,
            data: {
              image: image,
              username: docker_username,
              password: docker_password
            }
          }
          PackageCreateMessage.new(data)
        end

        it 'redacts the password field' do
          expect(message.audit_hash).to eq({
                                             'relationships' => relationships.deep_stringify_keys,
                                             'type' => 'docker',
                                             'data' => {
                                               'image' => image,
                                               'username' => docker_username,
                                               'password' => '***'
                                             }
                                           })
        end
      end

      context 'when a data field is not present' do
        let(:message) do
          data = {
            type: 'buildpack',
            relationships: relationships
          }
          PackageCreateMessage.new(data)
        end

        it 'returns the audit_hash' do
          expect(message.audit_hash).to eq({
                                             'relationships' => relationships.deep_stringify_keys,
                                             'type' => 'buildpack'
                                           })
        end
      end
    end
  end
end
