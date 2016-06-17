require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Files', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  authenticated_request

  let(:app_obj) { VCAP::CloudController::AppFactory.make(state: 'STARTED', package_hash: 'abc') }
  let(:app_guid) { app_obj.guid }
  let(:instance_index) { '0' }
  let(:file_path) { 'path_to_file' }

  get '/v2/apps/:app_guid/instances/:instance_index/files/:file_path' do
    example 'Retrieve File' do
      explanation <<-EOD
        The endpoint does not function with Diego apps.
        Please use CF CLI command `cf ssh` for Diego apps.
      EOD

      deal_file_result = VCAP::CloudController::Dea::FileUriResult.new(
        credentials: [],
        file_uri_v2: 'dea.example.com/encoded_path_to_file',
      )
      expect(VCAP::CloudController::Dea::Client).to receive(:get_file_uri_for_active_instance_by_index).and_return(deal_file_result)

      client.get "/v2/apps/#{app_guid}/instances/#{instance_index}/files/#{file_path}", {}, headers
      expect(status).to eq(302)
      expect(response_headers['Location']).to eq('dea.example.com/encoded_path_to_file')
    end
  end
end
