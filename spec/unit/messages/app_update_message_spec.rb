require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  RSpec.describe AppUpdateMessage do
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
                        stack: 'cflinuxfs3'
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
            expect(message.errors_on(:lifecycle_data)).to include('must be an object')
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

        context 'when lifecycle data is empty' do
          let(:params) do
            {
                lifecycle: {
                    data: {}
                }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle type is not provided, but buildpacks are' do
          let(:params) do
            {
              lifecycle: {
                data: {
                  buildpacks: ['java'],
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle data is not an object' do
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

            expect(message.errors_on(:lifecycle_data)).to include('must be an object')
          end
        end
      end
      describe 'metadata' do
        it 'can parse labels' do
          params =
            {
                metadata: {
                    labels: {
                        potato: 'mashed'
                    }
                }
            }
          message = AppUpdateMessage.new(params)
          expect(message).to be_valid
          expect(message.labels).to include(potato: 'mashed')
        end

        it 'validates labels' do
          params = {
              metadata: {
                  labels: 'potato',
              }
          }
          message = AppUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:metadata)).to include("'labels' is not an object")
        end
        it 'can parse annotations' do
          params =
            {
              metadata: {
                annotations: {
                  potato: 'mashed',
                  delete: nil,
                }
              }
            }
          message = AppUpdateMessage.new(params)
          expect(message).to be_valid
          expect(message.annotations).to include(potato: 'mashed')
          expect(message.annotations).to include(delete: nil)
        end

        it 'validates annotations' do
          params = {
            metadata: {
              annotations: 'potato',
            }
          }
          message = AppUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:metadata)).to include("'annotations' is not an object")
        end
      end
    end
  end
end
