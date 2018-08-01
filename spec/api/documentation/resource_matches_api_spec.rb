require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Resource Match', type: [:api, :legacy_api] do
  include_context 'resource pool'

  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  authenticated_request

  put '/v2/resource_match' do
    example 'List all matching resources' do
      explanation 'This endpoint matches given resource SHA / file size pairs against the Cloud Controller cache,
        and reports the subset which describes already existing files.
        This is usually used to avoid uploading duplicate files when
        pushing an app which has only been partially changed.
        Cloud Foundry operators may set minimum / maximum file sizes to match against.
        If the file size provided is outside this range, it will not be matched against.'
      @resource_pool.add_directory(@tmpdir)
      resources = [@descriptors.first] + [@dummy_descriptor]
      encoded_resources = MultiJson.dump(resources, pretty: true)
      client.put '/v2/resource_match', encoded_resources, headers
      expect(status).to eq(200)
    end
  end
end
