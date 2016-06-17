require 'spec_helper'

RSpec.describe 'Processes' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my_app') }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer) }

  describe 'GET /v3/processes' do
    let!(:web_process) {
      VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )
    }
    let!(:worker_process) {
      VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'worker',
        instances:  1,
        memory:     100,
        disk_quota: 200,
        command:    'start worker',
      )
    }

    before { VCAP::CloudController::ProcessModel.make(:process, app: app_model, space: space) }

    it 'returns a paginated list of processes' do
      get '/v3/processes?per_page=2', nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'total_pages'   => 2,
          'first'         => { 'href' => '/v3/processes?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'         => web_process.guid,
            'type'         => 'web',
            'command'      => '[PRIVATE DATA HIDDEN IN LISTS]',
            'instances'    => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'ports'        => [8080],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{web_process.guid}" },
              'scale' => { 'href' => "/v3/processes/#{web_process.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'stats' => { 'href' => "/v3/processes/#{web_process.guid}/stats" },
            },
          },
          {
            'guid'         => worker_process.guid,
            'type'         => 'worker',
            'command'      => '[PRIVATE DATA HIDDEN IN LISTS]',
            'instances'    => 1,
            'memory_in_mb' => 100,
            'disk_in_mb'   => 200,
            'ports'        => [],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{worker_process.guid}" },
              'scale' => { 'href' => "/v3/processes/#{worker_process.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'stats' => { 'href' => "/v3/processes/#{worker_process.guid}/stats" },
            },
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted list' do
      context 'by types' do
        it 'returns only the matching processes' do
          get '/v3/processes?per_page=2&types=worker,doesnotexist', nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => '/v3/processes?page=1&per_page=2&types=worker%2Cdoesnotexist' },
            'last'          => { 'href' => '/v3/processes?page=1&per_page=2&types=worker%2Cdoesnotexist' },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([worker_process.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by space_guids' do
        let!(:other_space) { VCAP::CloudController::Space.make(organization: space.organization) }
        let!(:other_space_process) {
          VCAP::CloudController::ProcessModel.make(
            :process,
            app:        other_app_model,
            space:      other_space,
            type:       'web',
            instances:  2,
            memory:     1024,
            disk_quota: 1024,
            command:    'rackup',
          )
        }
        let(:other_app_model) { VCAP::CloudController::AppModel.make(space: other_space) }

        before do
          other_space.add_developer developer
        end

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&space_guids=#{other_space.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/processes?page=1&per_page=2&space_guids=#{other_space.guid}" },
            'last'          => { 'href' => "/v3/processes?page=1&per_page=2&space_guids=#{other_space.guid}" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([other_space_process.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by organization guids' do
        let(:other_space) { VCAP::CloudController::Space.make }
        let!(:other_org) { other_space.organization }
        let!(:other_space_process) {
          VCAP::CloudController::ProcessModel.make(
            :process,
            app:        other_app_model,
            space:      other_space,
            type:       'web',
            instances:  2,
            memory:     1024,
            disk_quota: 1024,
            command:    'rackup',
          )
        }
        let(:other_app_model) { VCAP::CloudController::AppModel.make(space: other_space) }
        let(:developer) { make_developer_for_space(other_space) }

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&organization_guids=#{other_org.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/processes?organization_guids=#{other_org.guid}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/processes?organization_guids=#{other_org.guid}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([other_space_process.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by app guids' do
        let!(:desired_process) do
          VCAP::CloudController::ProcessModel.make(:process,
            space:      space,
            type:       'persnickety',
            instances:  3,
            memory:     2048,
            disk_quota: 2048,
            command:    'at ease'
          )
        end
        let(:desired_app) { desired_process.app }

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&app_guids=#{desired_app.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/processes?app_guids=#{desired_app.guid}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/processes?app_guids=#{desired_app.guid}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([desired_process.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by guids' do
        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&guids=#{web_process.guid},#{worker_process.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 2,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/processes?guids=#{web_process.guid}%2C#{worker_process.guid}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/processes?guids=#{web_process.guid}%2C#{worker_process.guid}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([web_process.guid, worker_process.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end
    end
  end

  describe 'GET /v3/processes/:guid' do
    it 'retrieves the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      get "/v3/processes/#{process.guid}", nil, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => nil,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'redacts information for auditors' do
      process = VCAP::CloudController::ProcessModel.make(:process, space: space, command: 'rackup')

      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/processes/#{process.guid}", nil, headers_for(auditor)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['command']).to eq('[PRIVATE DATA HIDDEN]')
    end
  end

  describe 'GET /v3/processes/:guid/stats' do
    it 'succeeds when TPS is an older version without net_info' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', app: app_model, space: space, diego: true)

      usage_time   = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        port:          8080,
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/apps/#{app_model.guid}/processes/worker/stats", nil, developer_headers

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'][0]['port']).to eq(8080)
    end

    it 'retrieves the stats for a process' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', space: space, diego: true)

      usage_time   = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        net_info:      {
          address: 'host',
          ports:   [
            { container_port: 7890, host_port: 5432 },
            { container_port: 8080, host_port: 1234 }
          ]
        },
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/processes/#{process.guid}/stats", nil, developer_headers

      expected_response = {
        'resources' => [{
          'type'           => 'worker',
          'index'          => 0,
          'state'          => 'RUNNING',
          'usage'          => {
            'time' => usage_time,
            'cpu'  => 80,
            'mem'  => 128,
            'disk' => 1024,
          },
          'host'           => 'toast',
          'instance_ports' => [
            {
              'external' => 5432,
              'internal' => 7890
            },
            {
              'external' => 1234,
              'internal' => 8080
            }
          ],
          'uptime'         => 1,
          'mem_quota'      => 1073741824,
          'disk_quota'     => 1073741824,
          'fds_quota'      => 16384
        }]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'PATCH /v3/processes/:guid' do
    it 'updates the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        diego:                true,
        app:                  app_model,
        space:                space,
        type:                 'web',
        instances:            2,
        memory:               1024,
        disk_quota:           1024,
        command:              'rackup',
        ports:                [4444, 5555],
        health_check_type:    'port',
        health_check_timeout: 10
      )

      update_request = {
        command:      'new command',
        ports:        [1234, 5678],
        health_check: {
          type: 'process',
          data: {
            timeout: 20
          }
        }
      }.to_json

      patch "/v3/processes/#{process.guid}", update_request, developer_headers.merge('CONTENT_TYPE' => 'application/json')

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'new command',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [1234, 5678],
        'health_check' => {
          'type' => 'process',
          'data' => {
            'timeout' => 20
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.command).to eq('new command')
      expect(process.health_check_type).to eq('process')
      expect(process.health_check_timeout).to eq(20)
      expect(process.ports).to match_array([1234, 5678])

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.process.update',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'command'      => 'PRIVATE DATA HIDDEN',
          'ports'        => [1234, 5678],
          'health_check' => {
            'type' => 'process',
            'data' => {
              'timeout' => 20,
            }
          }
        }
      })
    end
  end

  describe 'PUT /v3/processes/:guid/scale' do
    it 'scales the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
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
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
        type:              'audit.app.process.scale',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'instances'    => '5',
          'memory_in_mb' => '10',
          'disk_in_mb'   => '20'
        }
      })
    end
  end

  describe 'DELETE /v3/processes/:guid/instances/:index' do
    it 'terminates a single instance of a process' do
      process = VCAP::CloudController::ProcessModel.make(:process, space: space, type: 'web', app: app_model)

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:delete, "http://nsync.service.cf.internal:8787/v1/apps/#{process_guid}/index/0").to_return(status: 202, body: '')

      delete "/v3/processes/#{process.guid}/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events        = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
        type:              'audit.app.process.terminate_instance',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid'  => process.guid,
        'process_type'  => 'web',
        'process_index' => 0
      })
    end
  end

  describe 'GET /v3/apps/:guid/processes' do
    let!(:process1) {
      VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )
    }

    let!(:process2) {
      VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'worker',
        instances:  1,
        memory:     100,
        disk_quota: 200,
        command:    'start worker',
      )
    }

    let!(:process3) {
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, space: space)
    }

    it 'returns a paginated list of processes for an app' do
      get "/v3/apps/#{app_model.guid}/processes?per_page=2", nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'total_pages'   => 2,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'         => process1.guid,
            'type'         => 'web',
            'command'      => '[PRIVATE DATA HIDDEN IN LISTS]',
            'instances'    => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb'   => 1024,
            'ports'        => [8080],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process1.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process1.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'stats' => { 'href' => "/v3/processes/#{process1.guid}/stats" },
            },
          },
          {
            'guid'         => process2.guid,
            'type'         => 'worker',
            'command'      => '[PRIVATE DATA HIDDEN IN LISTS]',
            'instances'    => 1,
            'memory_in_mb' => 100,
            'disk_in_mb'   => 200,
            'ports'        => [],
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil
              }
            },
            'created_at'   => iso8601,
            'updated_at'   => nil,
            'links'        => {
              'self'  => { 'href' => "/v3/processes/#{process2.guid}" },
              'scale' => { 'href' => "/v3/processes/#{process2.guid}/scale", 'method' => 'PUT' },
              'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'stats' => { 'href' => "/v3/processes/#{process2.guid}/stats" },
            },
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted list' do
      context 'by types' do
        it 'returns only the matching processes' do
          get "/v3/apps/#{app_model.guid}/processes?per_page=2&types=worker", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=1&per_page=2&types=worker" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?page=1&per_page=2&types=worker" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([process2.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by guids' do
        it 'returns only the matching processes' do
          get "/v3/apps/#{app_model.guid}/processes?per_page=2&guids=#{process1.guid},#{process2.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 2,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/processes?guids=#{process1.guid}%2C#{process2.guid}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/processes?guids=#{process1.guid}%2C#{process2.guid}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          }

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([process1.guid, process2.guid])
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end
    end
  end

  describe 'GET /v3/apps/:guid/processes/:type' do
    it 'retrieves the process for an app with the requested type' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      get "/v3/apps/#{app_model.guid}/processes/web", nil, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb'   => 1024,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => nil,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'redacts information for auditors' do
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, type: 'web', space: space, command: 'rackup')

      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/apps/#{app_model.guid}/processes/web", nil, headers_for(auditor)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['command']).to eq('[PRIVATE DATA HIDDEN]')
    end
  end

  describe 'GET /v3/apps/:guid/processes/:type/stats' do
    it 'succeeds when TPS is an older version without net_info' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', app: app_model, space: space, diego: true)

      usage_time   = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        port:          8080,
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/apps/#{app_model.guid}/processes/worker/stats", nil, developer_headers

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'][0]['port']).to eq(8080)
    end

    it 'retrieves the stats for a process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'worker', app: app_model, space: space, diego: true)

      usage_time   = Time.now.utc.to_s
      tps_response = [{
        process_guid:  process.guid,
        instance_guid: 'instance-A',
        index:         0,
        state:         'RUNNING',
        details:       'some-details',
        uptime:        1,
        since:         101,
        host:          'toast',
        net_info:      {
          address: 'host',
          ports:   [
            { container_port: 7890, host_port: 5432 },
            { container_port: 8080, host_port: 1234 }
          ]
        },
        stats:         { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
      }].to_json

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:get, "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process_guid}/stats").to_return(status: 200, body: tps_response)

      get "/v3/apps/#{app_model.guid}/processes/worker/stats", nil, developer_headers

      expected_response = {
        'resources' => [{
          'type'           => 'worker',
          'index'          => 0,
          'state'          => 'RUNNING',
          'usage'          => {
            'time' => usage_time,
            'cpu'  => 80,
            'mem'  => 128,
            'disk' => 1024,
          },
          'host'           => 'toast',
          'instance_ports' => [
            {
              'external' => 5432,
              'internal' => 7890
            },
            {
              'external' => 1234,
              'internal' => 8080
            }
          ],
          'uptime'         => 1,
          'mem_quota'      => 1073741824,
          'disk_quota'     => 1073741824,
          'fds_quota'      => 16384
        }]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'PUT /v3/apps/:guid/processes/:type/scale' do
    it 'scales the process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app:        app_model,
        space:      space,
        type:       'web',
        instances:  2,
        memory:     1024,
        disk_quota: 1024,
        command:    'rackup',
      )

      scale_request = {
        instances:    5,
        memory_in_mb: 10,
        disk_in_mb:   20,
      }

      put "/v3/apps/#{app_model.guid}/processes/web/scale", scale_request, developer_headers

      expected_response = {
        'guid'         => process.guid,
        'type'         => 'web',
        'command'      => 'rackup',
        'instances'    => 5,
        'memory_in_mb' => 10,
        'disk_in_mb'   => 20,
        'ports'        => [8080],
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil
          }
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{space.guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        },
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
        type:              'audit.app.process.scale',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid' => process.guid,
        'process_type' => 'web',
        'request'      => {
          'instances'    => '5',
          'memory_in_mb' => '10',
          'disk_in_mb'   => '20'
        }
      })
    end
  end

  describe 'DELETE /v3/apps/:guid/processes/:type/instances/:index' do
    it 'terminates a single instance of a process belonging to an app' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'web', app: app_model, space: space)

      process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(process)
      stub_request(:delete, "http://nsync.service.cf.internal:8787/v1/apps/#{process_guid}/index/0").to_return(status: 202, body: '')

      delete "/v3/apps/#{app_model.guid}/processes/web/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events        = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
        type:              'audit.app.process.terminate_instance',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(process_event.metadata).to eq({
        'process_guid'  => process.guid,
        'process_type'  => 'web',
        'process_index' => 0
      })
    end
  end
end
