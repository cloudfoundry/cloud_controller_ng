require 'spec_helper'
require 'messages/security_group_list_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupListMessage do
    describe 'validations' do
      it 'accepts an empty set' do
        message = SecurityGroupListMessage.from_params({})
        expect(message).to be_valid
      end

      describe 'guids' do
        it 'is invalid if guids is not an array' do
          message = SecurityGroupListMessage.from_params guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'accepts and array of guids' do
          message = SecurityGroupListMessage.from_params guids: ['some-guid']
          expect(message).to be_valid
        end
      end

      describe 'names' do
        it 'is invalid if names is not an array' do
          message = SecurityGroupListMessage.from_params names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'accepts and array of names' do
          message = SecurityGroupListMessage.from_params names: ['some-name']
          expect(message).to be_valid
        end
      end

      describe 'running space guids' do
        it 'is invalid if running space guids is not an array' do
          message = SecurityGroupListMessage.from_params running_space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:running_space_guids].length).to eq 1
        end

        it 'accepts and array of running space guids' do
          message = SecurityGroupListMessage.from_params running_space_guids: ['some-guid']
          expect(message).to be_valid
        end
      end

      describe 'staging_space_guids' do
        it 'is invalid if staging space guids is not an array' do
          message = SecurityGroupListMessage.from_params staging_space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:staging_space_guids].length).to eq 1
        end

        it 'accepts and array of staging space guids' do
          message = SecurityGroupListMessage.from_params staging_space_guids: ['some-guid']
          expect(message).to be_valid
        end
      end

      describe 'globally enabled running' do
        it 'accepts a boolean-like string value' do
          message = SecurityGroupListMessage.from_params globally_enabled_running: 'true'
          expect(message).to be_valid
        end

        it 'is invalid if globally enabled running is not a boolean-like string' do
          message = SecurityGroupListMessage.from_params globally_enabled_running: 'not a boolean'
          expect(message).to be_invalid
          expect(message.errors[:globally_enabled_running].length).to eq 1
        end
      end

      describe 'globally enabled staging' do
        it 'accepts a boolean-like string value' do
          message = SecurityGroupListMessage.from_params globally_enabled_staging: 'true'
          expect(message).to be_valid
        end

        it 'is invalid if globally enabled staging is not a boolean-like string' do
          message = SecurityGroupListMessage.from_params globally_enabled_staging: 'not a boolean'
          expect(message).to be_invalid
          expect(message.errors[:globally_enabled_staging].length).to eq 1
        end
      end

      it 'accepts pagination fields' do
        message = SecurityGroupListMessage.from_params({ page: 1, per_page: 5, order_by: 'updated_at' })
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = SecurityGroupListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
