require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Resource Match", type: :api do
  include_context "resource pool"

  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  authenticated_request

  put "/v2/resource_match" do
    example "List all matching resources" do
      @resource_pool.add_directory(@tmpdir)
      resources = [@descriptors.first] + [@dummy_descriptor]
      encoded_resources = MultiJson.dump(resources, pretty: true)
      client.put "/v2/resource_match", encoded_resources, headers
      expect(status).to eq(200)
    end
  end
end
