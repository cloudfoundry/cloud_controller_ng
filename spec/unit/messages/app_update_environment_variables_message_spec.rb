require 'spec_helper'
require 'messages/apps/app_update_environment_variables_message'

module VCAP::CloudController
  RSpec.describe AppUpdateEnvironmentVariablesMessage do
    let(:valid_body) {
      {
        'ENV_VAR' => 'env-value',
        'ANOTHER_VAR' => 'another-value',
      }
    }

    describe '.create_from_http_request' do
      it 'returns a Message containing the requested env vars' do
        message = AppUpdateEnvironmentVariablesMessage.create_from_http_request(valid_body)

        expect(message.environment_variables).to eq({
          ENV_VAR: 'env-value',
          ANOTHER_VAR: 'another-value',
        })
      end
    end

    describe 'validations' do
      it 'returns no validation errors on a valid request' do
        message = AppUpdateEnvironmentVariablesMessage.new(environment_variables: valid_body.deep_symbolize_keys)

        expect(message).to be_valid
      end

      it 'returns a validation error when `PORT` is specified' do
        invalid_body = {
          'PORT' => 8080,
        }
        message = AppUpdateEnvironmentVariablesMessage.new(environment_variables: invalid_body.deep_symbolize_keys)

        expect(message).not_to be_valid
        expect(message.errors_on(:environment_variables)[0]).to include('PORT')
      end

      it 'returns a validation error when `VCAP_` prefix is specified' do
        invalid_body = {
          'VCAP_VAR' => 'not-allowed',
        }
        message = AppUpdateEnvironmentVariablesMessage.new(environment_variables: invalid_body.deep_symbolize_keys)

        expect(message).not_to be_valid
        expect(message.errors_on(:environment_variables)[0]).to include('VCAP_')
      end
    end
  end
end
