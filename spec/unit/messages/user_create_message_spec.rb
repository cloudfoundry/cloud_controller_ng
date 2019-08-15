require 'spec_helper'
require 'messages/user_create_message'

module VCAP::CloudController
  RSpec.describe UserCreateMessage do
    subject { UserCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) { { guid: 'some-user-guid' } }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}
        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:guid]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            guid: 'some-user-guid'
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'guid' do
        context 'when not a string' do
          let(:params) do
            { guid: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:guid]).to include('must be a string')
          end
        end

        context 'when it is too short' do
          let(:params) { { guid: '' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:guid]).to include 'is too short (minimum is 1 character)'
          end
        end

        context 'when it is too long' do
          let(:params) { { guid: 'B' * (250 + 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:guid]).to include 'is too long (maximum is 250 characters)'
          end
        end

        context 'when it contains invalid characters' do
          let(:params) { { guid: '_!@#$%^&*().swag' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:guid]).to include 'must consist of alphanumeric characters and hyphens'
          end
        end
      end
    end
  end
end
