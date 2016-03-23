require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Processes (Experimental)', type: :api do
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

  get '/v3/processes/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make space: space }
    let(:process) { VCAP::CloudController::AppFactory.make app_guid: app_model.guid, space: space }
    let(:guid) { process.guid }
    let(:type) { process.type }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Get a Process' do
      expect(process.app_guid).to be_present

      expected_response = {
        'guid'         => guid,
        'type'         => type,
        'command'      => nil,
        'instances'    => 1,
        'memory_in_mb' => 1024,
        'disk_in_mb' => 1024,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links' => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      do_request_with_error_handling
      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  put '/v3/processes/:guid/scale' do
    body_parameter :instances, 'Number of instances'
    body_parameter :memory_in_mb, 'The memory in mb allocated per instance'
    body_parameter :disk_in_mb, 'The disk in mb allocated per instance'
    header 'Content-Type', 'application/json'

    let(:instances) { 3 }
    let(:memory_in_mb) { 100 }
    let(:disk_in_mb) { 100 }
    let(:guid) { process.guid }
    let(:raw_post) { body_parameters }

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
        'guid'         => process.guid,
        'type'         => process.type,
        'command'      => process.command,
        'instances'    => instances,
        'memory_in_mb' => memory_in_mb,
        'disk_in_mb' => disk_in_mb,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links' => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/processes/:guid/stats' do
    header 'Content-Type', 'application/json'

    let(:process) { VCAP::CloudController::AppFactory.make(state: 'STARTED', diego: true) }
    let(:guid) { process.guid }
    let(:usage_time) { Time.now.utc.to_s }
    let(:tps_response) do
      [{
        process_guid: guid,
        instance_guid: 'instance-A',
        index: 0,
        state: 'RUNNING',
        details: 'some-details',
        uptime: 1,
        since: 101,
        host: 'toast',
        port: 8080,
        stats: { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json
    end

    before do
      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)
      app = VCAP::CloudController::AppModel.make
      process.app_guid = app.guid
      process.save
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Get Detailed Stats for a Process' do
      do_request_with_error_handling

      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/processes/#{process.guid}/stats" },
          'last'          => { 'href' => "/v3/processes/#{process.guid}/stats" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [{
          'type' => process.type,
          'index' => 0,
          'state' => 'RUNNING',
          'usage' => {
            'time' => usage_time,
            'cpu' => 80,
            'mem' => 128,
            'disk' => 1024,
          },
          'host' => 'toast',
          'port' => 8080,
          'uptime' => 1,
          'mem_quota' => 1073741824,
          'disk_quota' => 1073741824,
          'fds_quota' => 16384
        }]
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  delete '/v3/processes/:guid/instances/:index' do
    body_parameter :guid, 'Process guid'
    body_parameter :index, 'The index of the instance to terminate'

    let(:guid) { process.guid }
    let(:index) { 0 }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Terminating a Process instance' do
      do_request_with_error_handling

      expect(response_status).to eq(204)
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
      process.reload
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
        'resources' => [
          {
            'guid'         => process.guid,
            'type'         => process.type,
            'instances'    => 1,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'command'      => nil,
            'created_at'   => iso8601,
            'updated_at'   => iso8601,
            'links' => {
              'self'  => { 'href' => "/v3/processes/#{process.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
              'space' => { 'href' => "/v2/spaces/#{process.space_guid}" }
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
        'guid'         => process.guid,
        'type'         => process.type,
        'command'      => nil,
        'instances'    => 1,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links' => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      do_request_with_error_handling
      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  put '/v3/apps/:guid/processes/:type/scale' do
    body_parameter :instances, 'Number of instances'
    body_parameter :memory_in_mb, 'The memory in mb allocated per instance'
    body_parameter :disk_in_mb, 'The disk in mb allocated per instance'

    let(:instances) { 3 }
    let(:memory_in_mb) { 100 }
    let(:disk_in_mb) { 100 }
    let(:guid) { app_model.guid }
    let(:type) { process.type }
    let(:raw_post) { body_parameters }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    header 'Content-Type', 'application/json'

    example 'Scaling a Process from its App' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::Event.count }.by(1)
      process.reload

      expected_response = {
        'guid'         => process.guid,
        'type'         => process.type,
        'command'      => process.command,
        'instances'    => instances,
        'memory_in_mb' => memory_in_mb,
        'disk_in_mb'   => disk_in_mb,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links' => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/apps/:guid/processes/:type/stats' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space, diego: true) }
    let(:guid) { app_model.guid }
    let(:type) { 'web' }
    let(:usage_time) { Time.now.utc.to_s }
    let(:tps_response) do
      [{
        process_guid: guid,
        instance_guid: 'instance-A',
        index: 0,
        state: 'RUNNING',
        details: 'some-details',
        uptime: 1,
        since: 101,
        host: 'toast',
        port: 8080,
        stats: { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json
    end

    before do
      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_app(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)
      process.app_guid = app_model.guid
      process.save
      process.space.organization.add_user user
      process.space.add_developer user
    end

    header 'Content-Type', 'application/json'

    example "Get Detailed Stats for an App's Process" do
      do_request_with_error_handling

      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes/web/stats" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes/web/stats" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [{
          'type' => process.type,
          'index' => 0,
          'state' => 'RUNNING',
          'usage' => {
            'time' => usage_time,
            'cpu' => 80,
            'mem' => 128,
            'disk' => 1024,
          },
          'host' => 'toast',
          'port' => 8080,
          'uptime' => 1,
          'mem_quota' => 1073741824,
          'disk_quota' => 1073741824,
          'fds_quota' => 16384
        }]
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  delete '/v3/apps/:guid/processes/:type/instances/:index' do
    body_parameter :guid, 'App guid'
    body_parameter :type, 'The type of instance', example_values: ['web', 'worker']
    body_parameter :index, 'The index of the instance to terminate'

    let(:guid) { app_model.guid }
    let(:type) { process.type }
    let(:index) { 0 }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Terminating a Process instance from its App' do
      do_request_with_error_handling

      expect(response_status).to eq(204)
    end
  end
end
