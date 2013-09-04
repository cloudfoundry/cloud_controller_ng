require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthTokensController, :services, type: :controller do
    include_examples "uaa authenticated api", path: "/v2/service_auth_tokens"
    include_examples "enumerating objects", path: "/v2/service_auth_tokens", model: ServiceAuthToken
    include_examples "reading a valid object", path: "/v2/service_auth_tokens", model: ServiceAuthToken, basic_attributes: %w(label provider)
    include_examples "operations on an invalid object", path: "/v2/service_auth_tokens"
    include_examples "deleting a valid object", path: "/v2/service_auth_tokens", model: ServiceAuthToken, one_to_many_collection_ids: {}, one_to_many_collection_ids_without_url: {}
    include_examples "creating and updating", path: "/v2/service_auth_tokens",
                     model: ServiceAuthToken,
                     required_attributes: %w(label provider token),
                     unique_attributes: %w(label provider),
                     extra_attributes: {token: ->{Sham.token}}
  end
end
