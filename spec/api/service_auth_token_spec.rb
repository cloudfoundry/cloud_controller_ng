# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthToken do
    include_examples "uaa authenticated api", path: "/v2/service_auth_tokens"
    include_examples "enumerating objects", path: "/v2/service_auth_tokens", model: Models::ServiceAuthToken
    include_examples "reading a valid object", path: "/v2/service_auth_tokens", model: Models::ServiceAuthToken, basic_attributes: %w(label provider)
    include_examples "operations on an invalid object", path: "/v2/service_auth_tokens"
    include_examples "deleting a valid object", path: "/v2/service_auth_tokens", model: Models::ServiceAuthToken, one_to_many_collection_ids: {}, one_to_many_collection_ids_without_url: {}
    include_examples "creating and updating", path: "/v2/service_auth_tokens", model: Models::ServiceAuthToken, required_attributes: %w(label provider token), unique_attributes: %w(label provider), ci_attributes: %w(label provider), extra_attributes: %w(token)
  end
end
