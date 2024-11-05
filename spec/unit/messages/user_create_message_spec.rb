require 'spec_helper'
require 'messages/user_create_message'

module VCAP::CloudController
  RSpec.describe UserCreateMessage do
    subject { UserCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) do
          {
            guid: 'some-user-guid',
            'metadata' => {
              'labels' => { 'key' => 'value' },
              'annotations' => { 'key' => 'value' }
            }
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:guid]).to include("either 'guid' or 'username' and 'origin' must be provided")
        end
      end

      context 'when guid and username is provided' do
        let(:params) do
          {
            username: 'meow',
            guid: 'some-user-guid'
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:username]).to include("cannot be provided with 'guid'")
        end
      end

      context 'when guid and origin is provided' do
        let(:params) do
          {
            origin: 'meow',
            guid: 'some-user-guid'
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:origin]).to include("cannot be provided with 'guid'")
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

      describe 'guid' do
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
            expect(subject).not_to be_valid
            expect(subject.errors[:guid]).to include 'must be between 1 and 200 characters'
          end
        end

        context 'when it is too long' do
          let(:params) { { guid: 'B' * (250 + 1) } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:guid]).to include 'must be between 1 and 200 characters'
          end
        end
      end

      describe 'username' do
        context 'when not a string' do
          let(:params) do
            { username: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:username]).to include('must be a string')
          end
        end

        context 'when origin is missing' do
          let(:params) do
            { username: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:username]).to include("'origin' is missing")
          end
        end
      end

      describe 'origin' do
        context 'when not a string' do
          let(:params) do
            { origin: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:origin]).to include('must be a string')
          end
        end

        context 'when username is missing' do
          let(:params) do
            { origin: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:origin]).to include("'username' is missing")
          end
        end

        context 'when equal to "uaa"' do
          let(:params) do
            { origin: 'uaa' }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:origin]).to include("cannot be 'uaa' when creating a user by username")
          end
        end
      end
    end
  end
end
