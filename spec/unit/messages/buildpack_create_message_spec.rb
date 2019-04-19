require 'spec_helper'
require 'messages/buildpack_create_message'

module VCAP::CloudController
  RSpec.describe BuildpackCreateMessage do
    subject { BuildpackCreateMessage.new(params) }

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'meow', name: 'the-name' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'name' do
        context 'when it is non-alphanumeric' do
          let(:params) { { name: 'thë-name' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:name]).to include('is invalid')
          end
        end

        context 'when it contains hyphens' do
          let(:params) { { name: 'a-z' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { name: 'AZ' } }

          it { is_expected.to be_valid }
        end

        context 'when it is at max length' do
          let(:params) { { name: 'B' * BuildpackCreateMessage::MAX_BUILDPACK_NAME_LENGTH } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (BuildpackCreateMessage::MAX_BUILDPACK_NAME_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end
      end

      describe 'stack' do
        context 'when it is not a string' do
          let(:params) { { name: 'the-name', stack: 4 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:stack]).to include('must be a string')
          end
        end

        context 'when it is nil' do
          let(:params) { { name: 'the-name', stack: nil } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'the-name', stack: 'B' * (BuildpackCreateMessage::MAX_STACK_LENGTH + 1) } }

          it 'should return an error' do
            expect(subject).to be_invalid
            expect(subject.errors[:stack]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end
      end

      describe 'position' do
        context 'when it is zero' do
          let(:params) { { name: 'the-name', position: 0 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:position]).to include('must be greater than or equal to 1')
          end
        end

        context 'when it is negative' do
          let(:params) { { name: 'the-name', position: -1 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:position]).to include('must be greater than or equal to 1')
          end
        end

        context 'when it is not an integer' do
          let(:params) { { name: 'the-name', position: 7.77 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:position]).to include('must be an integer')
          end
        end

        context 'when it is a positive integer' do
          let(:params) { { name: 'the-name', position: 1 } }

          it { is_expected.to be_valid }
        end
      end

      describe 'enabled' do
        context 'when it is not a boolean' do
          let(:params) { { name: 'the-name', enabled: 7.77 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:enabled]).to include('must be a boolean')
          end
        end

        context 'when it is a boolean' do
          let(:params) { { name: 'the-name', enabled: true } }

          it { is_expected.to be_valid }
        end
      end

      describe 'locked' do
        context 'when locked is not a boolean' do
          let(:params) { { name: 'the-name', locked: 7.77 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:locked]).to include('must be a boolean')
          end
        end

        context 'when locked is a boolean' do
          let(:params) { { name: 'the-name', locked: true } }

          it { is_expected.to be_valid }
        end
      end
    end
  end
end
