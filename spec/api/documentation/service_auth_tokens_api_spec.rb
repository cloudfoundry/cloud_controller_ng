require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'ServiceAuthTokens (deprecated)', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:guid) { VCAP::CloudController::ServiceAuthToken.first.guid }
  let!(:service_auth_tokens) { 3.times { VCAP::CloudController::ServiceAuthToken.make } }

  authenticated_request

  field :guid, 'The guid of the service auth token.', required: false
  field :label, 'Human readable name for the auth token', required: false, readonly: true, example_values: ['Nic-Token']
  field :provider, 'Human readable name of service provider', required: false, readonly: true, example_values: ['Face-Offer']
  field :token, 'The secret auth token used for authenticating', required: false, readonly: true

  standard_model_list(:service_auth_token, VCAP::CloudController::ServiceAuthTokensController)
  standard_model_get(:service_auth_token)
  standard_model_delete(:service_auth_token)

  get '/v2/service_auth_tokens' do
    standard_list_parameters VCAP::CloudController::ServiceAuthTokensController

    describe 'querying by label' do
      let(:q) { 'label:Nic-Token' }

      before do
        VCAP::CloudController::ServiceAuthToken.make label: 'Nic-Token'
      end

      example 'Filtering the result set by label' do
        client.get '/v2/service_auth_tokens', params, headers

        expect(status).to eq(200)

        standard_paginated_response_format? parsed_response

        expect(parsed_response['resources'].size).to eq(1)

        standard_entity_response(
          parsed_response['resources'].first,
          :service_auth_token,
          label: 'Nic-Token')
      end
    end

    describe 'querying by provider' do
      let(:q) { 'provider:Face-Offer' }

      before do
        VCAP::CloudController::ServiceAuthToken.make provider: 'Face-Offer'
      end

      example 'Filtering the result set by provider' do
        client.get '/v2/service_auth_tokens', params, headers

        expect(status).to eq(200)

        standard_paginated_response_format? parsed_response

        expect(parsed_response['resources'].size).to eq(1)

        standard_entity_response(
          parsed_response['resources'].first,
          :service_auth_token,
          provider: 'Face-Offer')
      end
    end
  end
end
