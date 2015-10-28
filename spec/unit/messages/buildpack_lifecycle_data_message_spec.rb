require 'spec_helper'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  describe BuildpackLifecycleDataMessage do
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

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
          end
        end

        describe '#stack_name_must_be_in_db' do
          context 'when stack name is not in db' do
            let(:params) { { stack: 'fake_stax' } }

            it 'is not valid' do
              message = BuildpackLifecycleDataMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors.full_messages[0]).to include('Stack is invalid')
            end
          end
        end
      end

      context 'buildpack' do
        context 'when the buildpack is not a string' do
          let(:params) { { buildpack: 3 } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpack must be a string')
          end
        end

        context 'when the stack name is an empty string' do
          let(:params) { { buildpack: '' } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpack must be between 1 and 4096 characters')
          end
        end

        context 'when the stack name exceeds 4096 characters' do
          let(:long_string) { 'a' * 4097 }
          let(:params) { { buildpack: long_string } }

          it 'is not valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.full_messages[0]).to include('Buildpack must be between 1 and 4096 characters')
          end
        end

        context 'when the stack is not requested' do
          let(:params) { { buildpack: nil } }

          it 'is valid' do
            message = BuildpackLifecycleDataMessage.new(params)

            expect(message).to be_valid
          end
        end
      end
    end
  end
end
