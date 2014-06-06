require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthTokensController, :services do
    it_behaves_like "an authenticated endpoint", path: "/v2/service_auth_tokens"
    include_examples "enumerating objects", path: "/v2/service_auth_tokens", model: ServiceAuthToken
    include_examples "reading a valid object", path: "/v2/service_auth_tokens", model: ServiceAuthToken, basic_attributes: %w(label provider)
    include_examples "operations on an invalid object", path: "/v2/service_auth_tokens"
    include_examples "deleting a valid object", path: "/v2/service_auth_tokens", model: ServiceAuthToken, one_to_many_collection_ids: {}
    include_examples "creating and updating", path: "/v2/service_auth_tokens",
                     model: ServiceAuthToken,
                     required_attributes: %w(label provider token),
                     unique_attributes: %w(label provider),
                     extra_attributes: {token: ->{Sham.token}}
  end

  describe 'deprecation warning' do
    it 'adds the X-Cf-Warning to all endpoint responses' do
      service = Service.make(:v1)
      ServiceAuthToken.all.first.destroy

      auth_token_data = {
        label: service.label,
        provider: service.provider,
        token: "the-token"
      }

      get '/v2/service_auth_tokens', {}, admin_headers
      expect(last_response.status).to eq 200
      expect(last_response).to be_a_deprecated_response

      post '/v2/service_auth_tokens', auth_token_data.to_json, admin_headers
      expect(last_response.status).to eq 201
      expect(last_response).to be_a_deprecated_response

      auth_token_guid = decoded_response['metadata']['guid']

      get "/v2/service_auth_tokens/#{auth_token_guid}", {}, admin_headers
      expect(last_response.status).to eq 200
      expect(last_response).to be_a_deprecated_response

      put "/v2/service_auth_tokens/#{auth_token_guid}", {token: 'new-token'}.to_json, admin_headers
      expect(last_response.status).to eq 201
      expect(last_response).to be_a_deprecated_response

      delete "/v2/service_auth_tokens/#{auth_token_guid}", {}, admin_headers
      expect(last_response.status).to eq 204
      expect(last_response).to be_a_deprecated_response
    end
  end
end
