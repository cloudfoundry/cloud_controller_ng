require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  describe AppUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'name' => 'some-name',
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpack' => 'some-buildpack',
              'stack' => 'some-stack'
            }
          },
          'environment_variables' => {
            'ENVVAR' => 'env-val'
          }
        }
      }

      it 'returns the correct AppUpdateMessage' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(AppUpdateMessage)
        expect(message.name).to eq('some-name')
        expect(message.lifecycle['data']['buildpack']).to eq('some-buildpack')
        expect(message.lifecycle['data']['stack']).to eq('some-stack')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
      end

      it 'converts requested keys to symbols' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
        expect(message.requested?(:lifecycle)).to be_truthy
        expect(message.requested?(:environment_variables)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when environment_variables is not a hash' do
        let(:params) { { environment_variables: 'potato' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)[0]).to include('must be a hash')
        end
      end

      describe 'lifecycle' do
        context 'when lifecycle is provided' do
          let(:params) do
            {
              name: 'some_name',
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: 'java',
                  stack: 'cflinuxfs2'
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle data is provided' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: 123,
                  stack: 324
                }
              }
            }
          end

          it 'must provide a valid buildpack value' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpack must be a string')
          end

          it 'must provide a valid stack name' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Stack must be a string')
          end
        end

        context 'when data is not provided' do
          let(:params) do { lifecycle: { type: 'buildpack' } } end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end

        context 'when lifecycle is not provided' do
          let(:params) do
            {
              name: 'some_name',
            }
          end

          it 'does not supply defaults' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
            expect(message.lifecycle).to eq(nil)
          end
        end

        context 'when lifecycle type is not provided' do
          let(:params) do
            {
              lifecycle: {
                data: {}
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_type)).to include('must be a string')
          end
        end

        context 'when lifecycle data is not a hash' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: 'potato'
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end
      end
    end
  end
end
