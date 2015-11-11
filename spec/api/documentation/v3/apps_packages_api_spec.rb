require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = MultiJson.load(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/apps/:guid/packages' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'

    let(:space) { VCAP::CloudController::Space.make }
    let!(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    example 'List associated packages' do
      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{guid}/packages?page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps/#{guid}/packages?page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources'  => [
          {
            'guid'       => package.guid,
            'type'       => 'bits',
            'data'       => {
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'error'      => nil
            },
            'url'        => nil,
            'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
            'created_at' => iso8601,
            'updated_at' => nil,
            'links'     => {
              'self'   => { 'href' => "/v3/packages/#{package.guid}" },
              'upload' => { 'href' => "/v3/packages/#{package.guid}/upload", 'method' => 'POST' },
              'download' => { 'href' => "/v3/packages/#{package.guid}/download", 'method' => 'GET' },
              'stage' => { 'href' => "/v3/packages/#{package.guid}/droplets", 'method' => 'POST' },
              'app'    => { 'href' => "/v3/apps/#{guid}" },
            }
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
