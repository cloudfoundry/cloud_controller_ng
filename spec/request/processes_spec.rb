require 'spec_helper'

describe 'Processes' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer) }

  describe 'GET /v3/processes' do
    it 'returns a paginated list of processes' do
      process1 = VCAP::CloudController::ProcessModel.make(
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
        metadata:   {}
      )
      process2 = VCAP::CloudController::ProcessModel.make(
        app:        app_model,
        space:      space,
        type:       'worker',
        instances:  1,
        memory:     100,
        disk_quota: 200,
        command:    'start worker',
        metadata:   {}
      )
      VCAP::CloudController::ProcessModel.make(app: app_model, space: space)

      get '/v3/processes?per_page=2', nil, developer_headers

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
            'guid'         => process1.guid,
            'type'         => 'web',
            'command'      => 'rackup',
            'instances'    => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process1.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process1.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          },
          {
            'guid'         => process2.guid,
            'type'         => 'worker',
            'command'      => 'start worker',
            'instances'    => 1,
            'memory_in_mb' => 100,
            'disk_in_mb'   => 200,
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process2.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process2.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
            },
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/processes:guid' do
    it 'retrieves the process' do
      process = VCAP::CloudController::ProcessModel.make(
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
        metadata:   {}
      )

      get "/v3/processes/#{process.guid}", nil, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'created_at'   => iso8601,
        'updated_at'   => nil,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'PATCH /v3/processes/:guid' do
    it 'updates the process' do
      process = VCAP::CloudController::ProcessModel.make(
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
        metadata:   {}
      )

      update_request = {
        command: 'new command'
      }

      patch "/v3/processes/#{process.guid}", update_request, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'new command',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.command).to eq('new command')

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.app.update')
      expect(event.actee).to eq(process.guid)
    end
  end

  describe 'PUT /v3/processes/:guid/scale' do
    it 'scales the process' do
      process = VCAP::CloudController::ProcessModel.make(
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
        metadata:   {}
      )

      scale_request = {
        instances:    5,
        memory_in_mb: 10,
        disk_in_mb:   20,
      }

      put "/v3/processes/#{process.guid}/scale", scale_request, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 5,
        'memory_in_mb' => 10,
        'disk_in_mb'   => 20,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.app.update')
      expect(event.actee).to eq(process.guid)
    end
  end
end
