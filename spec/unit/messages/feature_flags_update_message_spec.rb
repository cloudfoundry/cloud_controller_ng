require 'spec_helper'
require 'messages/feature_flags_update_message'

module VCAP::CloudController
  RSpec.describe FeatureFlagsUpdateMessage do
    subject { FeatureFlagsUpdateMessage.new(params) }

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'meow', name: 'the-name' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'error_message' do
        MAX_ERROR_MESSAGE_LENGTH = 250

        context 'when it contains hyphens' do
          let(:params) { { enabled: true, custom_error_message: 'a-z' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { enabled: true, custom_error_message: 'AZ' } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { enabled: true, custom_error_message: 'B' * (MAX_ERROR_MESSAGE_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:custom_error_message]).to eq ["is too long (maximum is #{MAX_ERROR_MESSAGE_LENGTH} characters)"]
          end
        end

        context 'when it is an empty string' do
          let(:params) { { enabled: true, custom_error_message: '' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:custom_error_message]).to eq ['is too short (minimum is 1 character)']
          end
        end
      end

      describe 'enabled' do
        context 'when it is not a boolean' do
          let(:params) { { enabled: 7.77 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:enabled]).to include('must be a boolean')
          end
        end

        context 'when it is a boolean' do
          let(:params) { { enabled: true } }

          it { is_expected.to be_valid }
        end

        context 'when it is null' do
          let(:params) { { enabled: nil } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:enabled]).to include('must be a boolean')
          end
        end
      end
    end
  end
end
