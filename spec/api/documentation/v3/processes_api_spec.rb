require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Processes (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = JSON.parse(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/processes' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'

    let(:name1) { 'my_process1' }
    let(:name2) { 'my_process2' }
    let(:name3) { 'my_process3' }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let!(:process1) { VCAP::CloudController::AppFactory.make(name: name1, space: space, app_guid: app_model.guid) }
    let!(:process2) { VCAP::CloudController::AppFactory.make(name: name2, space: space) }
    let!(:process3) { VCAP::CloudController::AppFactory.make(name: name3, space: space) }
    let!(:process4) { VCAP::CloudController::AppFactory.make(space: VCAP::CloudController::Space.make) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:page) { 1 }
    let(:per_page) { 2 }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Processes' do
      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => '/v3/processes?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources'  => [
          {
            'guid'       => process1.guid,
            'type'       => process1.type,
            'command'    => nil,
            'instances'  => 1,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            '_links'     => {
              'self'     => { 'href' => "/v3/processes/#{process1.guid}" },
              'scale'    => { 'href' => "/v3/processes/#{process1.guid}/scale", 'method' => 'PUT' },
              'app'      => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space'    => { 'href' => "/v2/spaces/#{process1.space_guid}" },
            },
          },
          {
            'guid'       => process2.guid,
            'type'       => process2.type,
            'command'    => nil,
            'instances'  => 1,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            '_links'     => {
              'self'     => { 'href' => "/v3/processes/#{process2.guid}" },
              'scale'    => { 'href' => "/v3/processes/#{process2.guid}/scale", 'method' => 'PUT' },
              'app'      => { 'href' => "/v3/apps/#{process2.app_guid}" },
              'space'    => { 'href' => "/v2/spaces/#{process2.space_guid}" },
            },
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/processes/:guid' do
    let(:process) { VCAP::CloudController::AppFactory.make }
    let(:guid) { process.guid }
    let(:type) { process.type }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Get a Process' do
      expected_response = {
        'guid'       => guid,
        'type'       => type,
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

  patch '/v3/processes/:guid' do
    let(:process) { VCAP::CloudController::AppFactory.make }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    parameter :command, 'Start command for process'

    let(:command) { 'X' }

    let(:guid) { process.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Updating a Process' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::Event.count }.by(1)
      process.reload

      expected_response = {
        'guid'       => guid,
        'type'       => process.type,
        'command'    => 'X',
        'instances'  => process.instances,
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

  put '/v3/processes/:guid/scale' do
    parameter :instances, 'Number of instances'

    let(:instances) { 3 }
    let(:guid) { process.guid }
    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    let(:process) { VCAP::CloudController::AppFactory.make }

    before do
      app = VCAP::CloudController::AppModel.make
      process.app_guid = app.guid
      process.save
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Scaling a Process' do
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
