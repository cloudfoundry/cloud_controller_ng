require 'spec_helper'
require 'messages/lifecycles/buildpack_lifecycle_data_message'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataMessage do
    describe 'validations' do
      context 'allowed keys' do
        context 'when the message contains something other than the allowed keys' do
          let(:params) { { infiltrator: 'hello!' } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include("Unknown field(s): 'infiltrator'")
          end
        end
      end

      context 'stack' do
        context 'when the stack is not a string' do
          let(:params) { { stack: 3 } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Stack must be a string')
          end
        end

        context 'when the stack name is an empty string' do
          let(:params) { { stack: '' } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Stack must be between 1 and 4096 characters')
          end
        end

        context 'when the stack name exceeds 4096 characters' do
          let(:long_string) { 'a' * 4097 }
          let(:params) { { stack: long_string } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Stack must be between 1 and 4096 characters')
          end
        end

        context 'when the stack is nil' do
          let(:params) { { stack: nil } }

          it 'is valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).to be_valid
          end
        end
      end

      context 'buildpacks' do
        context 'when buildpacks is not an array' do
          let(:params) { { buildpacks: 'foo-buildpack' } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpacks must be an array')
          end
        end

        context 'when more than one buildpack is requested' do
          let(:params) { { buildpacks: ['foo-buildpack', 'bar'] } }

          it 'is valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).to be_valid
          end
        end

        context 'when buildpacks is an empty array' do
          let(:params) { { buildpacks: [] } }

          it 'is valid' do
            message = BuildpackLifecycleDataMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when buildpacks is not requested' do
          let(:params) { { buildpacks: nil } }

          it 'is valid' do
            message = BuildpackLifecycleDataMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when buildpacks contains non-string values' do
          let(:params) { { buildpacks: [4] } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpacks can only contain strings')
          end
        end

        context 'when buildpacks contains an empty string' do
          let(:params) { { buildpacks: [''] } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpacks entries must be between 1 and 4096 characters')
          end
        end

        context 'when buildpacks contains a name exceeding 4096 characters' do
          let(:long_string) { 'a' * 4097 }
          let(:params) { { buildpacks: [long_string] } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpacks entries must be between 1 and 4096 characters')
          end
        end

        context 'when buildpacks contains a nil' do
          let(:params) { { buildpacks: [nil] } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpacks can only contain strings')
          end
        end
      end
    end
  end
end
