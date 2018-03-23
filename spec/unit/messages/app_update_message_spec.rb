require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  RSpec.describe AppUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'name' => 'some-name',
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['some-buildpack'],
              'stack' => 'some-stack'
            }
          }
        }
      }

      it 'returns the correct AppUpdateMessage' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(AppUpdateMessage)
        expect(message).to be_valid
        expect(message.name).to eq('some-name')
        expect(message.lifecycle[:data][:buildpacks].first).to eq('some-buildpack')
        expect(message.lifecycle[:data][:stack]).to eq('some-stack')
      end

      it 'converts requested keys to symbols' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
        expect(message.requested?(:lifecycle)).to be_truthy
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

      context 'when we have more than one error' do
        let(:params) { { name: 3.5, unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array([
            'Name must be a string',
            "Unknown field(s): 'unexpected'"
          ])
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
                  buildpacks: ['java'],
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
                  buildpacks: [123],
                  stack: 324
                }
              }
            }
          end

          it 'must provide a valid buildpack value' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpacks can only contain strings')
          end

          it 'must provide a valid stack name' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Stack must be a string')
          end
        end

        context 'when data is not provided' do
          let(:params) do
            { lifecycle: { type: 'buildpack' } }
          end

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

      describe 'command' do
        context 'when an empty command is specified' do
          let(:params) do
            {
              command: command
            }
          end
          let(:command) { '' }

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Command must be between 1 and 4096 characters')
          end
        end
      end
    end
  end
end
