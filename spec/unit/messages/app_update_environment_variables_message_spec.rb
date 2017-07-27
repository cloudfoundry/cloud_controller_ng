require 'spec_helper'
require 'messages/apps/app_update_environment_variables_message'

module VCAP::CloudController
  RSpec.describe AppUpdateEnvironmentVariablesMessage do
    let(:valid_body) {
      {
        'var' => {
          'ENV_VAR' => 'env-value',
          'ANOTHER_VAR' => 'another-value'
        }
      }
    }

    describe '.create_from_http_request' do
      it 'returns a Message containing the requested env vars' do
        message = AppUpdateEnvironmentVariablesMessage.create_from_http_request(valid_body)

        expect(message).to be_a(AppUpdateEnvironmentVariablesMessage)
        expect(message.var).to eq(
          {
            ENV_VAR: 'env-value',
            ANOTHER_VAR: 'another-value'
          })
      end

      it 'converts requested keys to symbols' do
        message = AppUpdateEnvironmentVariablesMessage.create_from_http_request(valid_body)

        expect(message.requested?(:var)).to be_truthy
      end
    end

    describe 'validations' do
      it 'returns no validation errors on a valid request' do
        message = AppUpdateEnvironmentVariablesMessage.new(valid_body.deep_symbolize_keys)

        expect(message).to be_valid
      end

      it 'returns a validation error when an unexpected key is given' do
        invalid_body = {
          unexpected: 'foo',
          var: {
            ENV_VAR: 'env-value',
            ANOTHER_VAR: 'another-value'
          }
        }
        message = AppUpdateEnvironmentVariablesMessage.new(invalid_body)

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
      end

      it 'returns a validation error when `PORT` is specified' do
        invalid_body = {
          var: {
            PORT: 8080
          }
        }
        message = AppUpdateEnvironmentVariablesMessage.new(invalid_body)

        expect(message).not_to be_valid
        expect(message.errors_on(:var)[0]).to include('PORT')
      end

      it 'returns a validation error when `VCAP_` prefix is specified' do
        invalid_body = {
          var: {
            VCAP_VAR: 'not-allowed'
          }
        }
        message = AppUpdateEnvironmentVariablesMessage.new(invalid_body)

        expect(message).not_to be_valid
        expect(message.errors_on(:var)[0]).to include('VCAP_')
      end
    end
  end
end
