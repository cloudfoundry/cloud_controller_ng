require 'spec_helper'
require 'messages/role_create_message'

module VCAP::CloudController
  RSpec.describe RoleCreateMessage do
    subject { RoleCreateMessage.new(params) }
    let(:user_guid) { 'user-guid' }
    let(:space_guid) { 'space-guid' }
    let(:params) do
      {
        type: 'some-role-type',
        relationships: {
          user: {
            data: { guid: user_guid }
          },
          space: {
            data: { guid: space_guid }
          }
        }
      }
    end

    describe 'validations' do
      context 'when valid params are given' do
        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}
        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:user_guid]).to include("can't be blank")
          expect(subject.errors[:space_guid]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            type: 'some-role-type',
            relationships: {
              user: { guid: user_guid },
              space: { guid: space_guid }
            }
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'user_guid' do
        context 'when not a string' do
          let(:user_guid) { 5 }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:user_guid]).to include('must be a string')
          end
        end

        context 'when it is too short' do
          let(:user_guid) { '' }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:user_guid]).to include 'must be between 1 and 200 characters'
          end
        end

        context 'when it is too long' do
          let(:user_guid) { 'B' * (200 + 1) }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:user_guid]).to include 'must be between 1 and 200 characters'
          end
        end
      end

      context 'space_guid' do
        context 'when not a string' do
          let(:space_guid) { 5 }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:space_guid]).to include('must be a string')
          end
        end

        context 'when it is too short' do
          let(:space_guid) { '' }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:space_guid]).to include 'must be between 1 and 200 characters'
          end
        end

        context 'when it is too long' do
          let(:space_guid) { 'B' * (200 + 1) }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:space_guid]).to include 'must be between 1 and 200 characters'
          end
        end
      end
    end
  end
end
