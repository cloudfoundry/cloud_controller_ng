require 'spec_helper'
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

  get '/v3/apps/:guid/processes' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'

    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }
    let!(:process) { VCAP::CloudController::AppFactory.make(space_guid: space.guid) }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.add_process_by_guid(process.guid)
    end

    example 'List associated processes' do
      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{guid}/processes?page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps/#{guid}/processes?page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources'  => [
          {
            'guid'    => process.guid,
            'type'    => process.type,
            'command' => nil,
            'created_at' => iso8601,
            'updated_at' => iso8601,
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/apps/:guid/processes/:type' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }
    let(:guid) { app_model.guid }
    let(:type) { process.type }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Get a Process from an App' do
      expected_response = {
        'guid'       => process.guid,
        'type'       => process.type,
        'command'    => nil,
        'instances'  => 1,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        '_links'     => {
          'self'     => { 'href' => "/v3/processes/#{process.guid}" },
          'scale'    => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'      => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space'    => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      do_request_with_error_handling
      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  put '/v3/apps/:guid/processes/:type/scale' do
    parameter :instances, 'Number of instances'

    let(:instances) { 3 }
    let(:guid) { app_model.guid }
    let(:type) { process.type }
    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Scaling a Process from its App' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::Event.count }.by(1)
      process.reload

      expected_response = {
        'guid'       => process.guid,
        'type'       => process.type,
        'command'    => process.command,
        'instances'  => instances,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        '_links'     => {
          'self'     => { 'href' => "/v3/processes/#{process.guid}" },
          'scale'    => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'      => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space'    => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
