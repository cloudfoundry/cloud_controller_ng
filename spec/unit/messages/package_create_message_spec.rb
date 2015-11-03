require 'spec_helper'
require 'messages/package_create_message'

module VCAP::CloudController
  describe PackageCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'type' => 'docker' } }

      it 'returns the correct PackageCreateMessage' do
        message = PackageCreateMessage.create_from_http_request('guid', body)

        expect(message).to be_a(PackageCreateMessage)
        expect(message.app_guid).to eq('guid')
        expect(message.type).to eq('docker')
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
          expect(message.errors[:type]).to include('must be one of \'bits, docker\'')
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

      context 'bits' do
        context 'when a data parameter is provided for a bits package and it is not empty' do
          let(:params) { { app_guid: 'guid', type: 'bits', data: { foobar: 'foobaz' } } }

          it 'is not valid' do
            message = PackageCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include('Data must be empty if provided for bits packages')
          end
        end

        context 'when a data parameter is not provided for a bits package' do
          let(:params) { { app_guid: 'guid', type: 'bits' } }

          it 'is valid' do
            message = PackageCreateMessage.new(params)
            expect(message).to be_valid
          end
        end
      end

      context 'when a docker type is requested' do
        context 'when an image is not provided' do
          let(:params) { { app_guid: 'guuid!', type: 'docker', data: { store_image: false, credentials: {} } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image required')
          end
        end

        context 'when a non-string image is provided' do
          let(:params) { { app_guid: 'guuid!', type: 'docker', data: { image: 5, store_image: false, credentials: {} } } }
          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Image must be a string')
          end
        end

        context 'when store_image is not provided' do
          let(:params) { { app_guid: 'guuid!', type: 'docker', data: { image: 'an-image' } } }
          it 'is valid' do
            message = PackageCreateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when a non-bool store_image is provided' do
          let(:params) { { app_guid: 'guuid!', type: 'docker', data: { store_image: 5, image: 'an-image', credentials: {} } } }

          it 'is invalid' do
            message = PackageCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Data Store image must be a boolean')
          end
        end

        context 'when credentials are provided' do
          let(:params) { { app_guid: 'guuid!', type: 'docker', data: { credentials: credentials } } }
          context 'and user is not present' do
            let(:credentials) do
              {
                password: 'password',
                email: 'email@example.com',
                login_server: 'https://index.docker.io/v1/'
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials user required')
            end
          end

          context 'and user is not a string' do
            let(:credentials) do
              {
                user: 5,
                password: 'password',
                email: 'email@example.com',
                login_server: 'https://index.docker.io/v1/'
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials user must be a string')
            end
          end

          context 'and password is not present' do
            let(:credentials) do
              {
                user: 'user',
                email: 'email@example.com',
                login_server: 'https://index.docker.io/v1/'
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials password required')
            end
          end

          context 'and password is not a string' do
            let(:credentials) do
              {
                user: 'user',
                email: 'email@example.com',
                login_server: 'https://index.docker.io/v1/',
                password: 5,
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials password must be a string')
            end
          end

          context 'and email is not present' do
            let(:credentials) do
              {
                user: 'user',
                password: 'password',
                login_server: 'https://index.docker.io/v1/'
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials email required')
            end
          end

          context 'and email is not a string' do
            let(:credentials) do
              {
                user: 'user',
                email: {},
                login_server: 'https://index.docker.io/v1/',
                password: '5',
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials email must be a string')
            end
          end

          context 'and login_server is not present' do
            let(:credentials) do
              {
                user: 'user',
                password: 'password',
                email: 'email@example.com',
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials login server required')
            end
          end

          context 'and login server is not a string' do
            let(:credentials) do
              {
                user: 'user',
                email: 'gee-email',
                login_server: ['server 1', 'this is not how this works'],
                password: '5',
              }
            end

            it 'is invalid' do
              message = PackageCreateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Data Credentials login server must be a string')
            end
          end
        end
      end
    end
  end
end
