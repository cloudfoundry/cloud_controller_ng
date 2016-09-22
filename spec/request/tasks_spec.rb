require 'spec_helper'

RSpec.describe 'Tasks' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:user) { VCAP::CloudController::User.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:droplet) do
    VCAP::CloudController::DropletModel.make(
      app_guid:     app_model.guid,
      state:        VCAP::CloudController::DropletModel::STAGED_STATE,
      droplet_hash: 'droplet-hash'
    )
  end
  let(:developer_headers) { headers_for(user) }

  before do
    space.organization.add_user user
    space.add_developer user

    stub_request(:post, 'http://nsync.service.cf.internal:8787/v1/tasks').to_return(status: 202)

    VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: true, error_message: nil)

    app_model.droplet = droplet
    app_model.save
  end

  describe 'GET /v3/tasks' do
    it 'returns a paginated list of tasks' do
      task1 = VCAP::CloudController::TaskModel.make(
        name:                  'task one',
        command:               'echo task',
        app_guid:              app_model.guid,
        droplet:               app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb:          5
      )
      task2 = VCAP::CloudController::TaskModel.make(
        name:         'task two',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 100,
      )
      VCAP::CloudController::TaskModel.make(
        app_guid: app_model.guid,
        droplet:  app_model.droplet,
      )

      get '/v3/tasks?per_page=2', nil, developer_headers

      expected_response =
        {
          'pagination' => {
            'total_results' => 3,
            'total_pages'   => 2,
            'first'         => { 'href' => '/v3/tasks?page=1&per_page=2' },
            'last'          => { 'href' => '/v3/tasks?page=2&per_page=2' },
            'next'          => { 'href' => '/v3/tasks?page=2&per_page=2' },
            'previous'      => nil,
          },
          'resources' => [
            {
              'guid'                  => task1.guid,
              'sequence_id'           => task1.sequence_id,
              'name'                  => 'task one',
              'state'                 => 'RUNNING',
              'memory_in_mb'          => 5,
              'result'                => {
                'failure_reason' => nil
              },
              'droplet_guid'          => task1.droplet.guid,
              'created_at'            => iso8601,
              'updated_at'            => nil,
              'links'                 => {
                'self' => {
                  'href' => "/v3/tasks/#{task1.guid}"
                },
                'app' => {
                  'href' => "/v3/apps/#{app_model.guid}"
                },
                'droplet' => {
                  'href' => "/v3/droplets/#{app_model.droplet.guid}"
                }
              }
            },
            {
              'guid'                  => task2.guid,
              'sequence_id'           => task2.sequence_id,
              'name'                  => 'task two',
              'state'                 => 'RUNNING',
              'memory_in_mb'          => 100,
              'result'                => {
                'failure_reason' => nil
              },
              'droplet_guid'          => task2.droplet.guid,
              'created_at'            => iso8601,
              'updated_at'            => nil,
              'links'                 => {
                'self' => {
                  'href' => "/v3/tasks/#{task2.guid}"
                },
                'app' => {
                  'href' => "/v3/apps/#{app_model.guid}"
                },
                'droplet' => {
                  'href' => "/v3/droplets/#{app_model.droplet.guid}"
                }
              }
            }
          ]
        }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'filtering' do
      it 'returns a paginated list of tasks' do
        task1 = VCAP::CloudController::TaskModel.make(
          name:                  'task one',
          command:               'echo task',
          app_guid:              app_model.guid,
          droplet:               app_model.droplet,
          environment_variables: { unicorn: 'magic' },
          memory_in_mb:          5,
          state:                 VCAP::CloudController::TaskModel::SUCCEEDED_STATE,
        )
        VCAP::CloudController::TaskModel.make(
          name:         'task two',
          command:      'echo task',
          app_guid:     app_model.guid,
          droplet:      app_model.droplet,
          memory_in_mb: 100,
        )
        VCAP::CloudController::TaskModel.make(
          app_guid: app_model.guid,
          droplet:  app_model.droplet,
        )

        query = {
          app_guids:          app_model.guid,
          names:              'task one',
          organization_guids: app_model.organization.guid,
          space_guids:        app_model.space.guid,
          states:             'SUCCEEDED'
        }

        get "/v3/tasks?#{query.to_query}", nil, developer_headers

        expected_query = "app_guids=#{app_model.guid}&names=task+one&organization_guids=#{app_model.organization.guid}" \
                            "&page=1&per_page=50&space_guids=#{app_model.space.guid}&states=SUCCEEDED"

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to eq([task1.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/tasks?#{expected_query}" },
            'last'          => { 'href' => "/v3/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end
    end
  end

  describe 'GET /v3/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make(
        name:                  'task',
        command:               'echo task',
        app_guid:              app_model.guid,
        droplet:               app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb:          5,
      )
      task_guid = task.guid

      get "/v3/tasks/#{task_guid}", nil, developer_headers

      expected_response = {
        'guid'                  => task_guid,
        'sequence_id'           => task.sequence_id,
        'name'                  => 'task',
        'command'               => 'echo task',
        'state'                 => 'RUNNING',
        'memory_in_mb'          => 5,
        'environment_variables' => { 'unicorn' => 'magic' },
        'result'                => {
          'failure_reason' => nil
        },
        'droplet_guid'          => task.droplet.guid,
        'created_at'            => iso8601,
        'updated_at'            => nil,
        'links'                 => {
          'self' => {
            'href' => "/v3/tasks/#{task_guid}"
          },
          'app' => {
            'href' => "/v3/apps/#{app_model.guid}"
          },
          'droplet' => {
            'href' => "/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'excludes information for auditors' do
      task = VCAP::CloudController::TaskModel.make(
        name:                  'task',
        command:               'echo task',
        app_guid:              app_model.guid,
        droplet:               app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb:          5,
      )
      task_guid = task.guid

      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/tasks/#{task_guid}", nil, headers_for(auditor)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).not_to have_key('command')
      expect(parsed_response).not_to have_key('environment_variables')
    end
  end

  describe 'PUT /v3/tasks/:guid/cancel' do
    it 'returns a json representation of the task with the requested guid' do
      task      = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', environment_variables: { unicorn: 'magic' }, app_guid: app_model.guid
      task_guid = task.guid

      stub_request(:delete, "http://nsync.service.cf.internal:8787/v1/tasks/#{task_guid}").to_return(status: 202)

      put "/v3/tasks/#{task_guid}/cancel", {}, admin_headers

      expect(last_response.status).to eq(202)
      parsed_body = JSON.load(last_response.body)
      expect(parsed_body['guid']).to eq(task_guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('CANCELING')
      expect(parsed_body['result']).to eq({ 'failure_reason' => nil })
      expect(parsed_body['environment_variables']).to eq({ 'unicorn' => 'magic' })
    end
  end

  describe 'GET /v3/apps/:guid/tasks' do
    it 'returns a paginated list of tasks' do
      task1 = VCAP::CloudController::TaskModel.make(
        name:                  'task one',
        command:               'echo task',
        app_guid:              app_model.guid,
        droplet:               app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb:          5,
      )
      task2 = VCAP::CloudController::TaskModel.make(
        name:         'task two',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 100,
      )
      VCAP::CloudController::TaskModel.make(
        app_guid: app_model.guid,
        droplet:  app_model.droplet,
      )

      get "/v3/apps/#{app_model.guid}/tasks?per_page=2", nil, developer_headers

      expected_response =
        {
          'pagination' => {
            'total_results' => 3,
            'total_pages'   => 2,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/tasks?page=1&per_page=2" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
            'next'          => { 'href' => "/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
            'previous'      => nil,
          },
          'resources' => [
            {
              'guid'                  => task1.guid,
              'sequence_id'           => task1.sequence_id,
              'name'                  => 'task one',
              'command'               => 'echo task',
              'state'                 => 'RUNNING',
              'memory_in_mb'          => 5,
              'environment_variables' => { 'unicorn' => 'magic' },
              'result'                => {
                'failure_reason' => nil
              },
              'droplet_guid'          => task1.droplet.guid,
              'created_at'            => iso8601,
              'updated_at'            => nil,
              'links'                 => {
                'self' => {
                  'href' => "/v3/tasks/#{task1.guid}"
                },
                'app' => {
                  'href' => "/v3/apps/#{app_model.guid}"
                },
                'droplet' => {
                  'href' => "/v3/droplets/#{app_model.droplet.guid}"
                }
              }
            },
            {
              'guid'                  => task2.guid,
              'sequence_id'           => task2.sequence_id,
              'name'                  => 'task two',
              'command'               => 'echo task',
              'state'                 => 'RUNNING',
              'memory_in_mb'          => 100,
              'environment_variables' => {},
              'result'                => {
                'failure_reason' => nil
              },
              'droplet_guid'          => task2.droplet.guid,
              'created_at'            => iso8601,
              'updated_at'            => nil,
              'links'                 => {
                'self' => {
                  'href' => "/v3/tasks/#{task2.guid}"
                },
                'app' => {
                  'href' => "/v3/apps/#{app_model.guid}"
                },
                'droplet' => {
                  'href' => "/v3/droplets/#{app_model.droplet.guid}"
                }
              }
            }
          ]
        }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'perms' do
      it 'exlcudes secrets when the user should not see them' do
        VCAP::CloudController::TaskModel.make(
          name:                  'task one',
          command:               'echo task',
          app_guid:              app_model.guid,
          droplet:               app_model.droplet,
          environment_variables: { unicorn: 'magic' },
          memory_in_mb:          5,
        )

        get "/v3/apps/#{app_model.guid}/tasks", nil, headers_for(make_auditor_for_space(space))

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'][0]).not_to have_key('command')
        expect(parsed_response['resources'][0]).not_to have_key('environment_variables')
      end
    end

    describe 'filtering' do
      it 'filters by name' do
        expected_task = VCAP::CloudController::TaskModel.make(name: 'task one', app: app_model)
        VCAP::CloudController::TaskModel.make(name: 'task two', app: app_model)

        query = { names: 'task one' }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = 'names=task+one&page=1&per_page=50'

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end

      it 'filters by state' do
        expected_task = VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE, app: app_model)
        VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::FAILED_STATE, app: app_model)

        query = { states: 'SUCCEEDED' }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = 'page=1&per_page=50&states=SUCCEEDED'

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end

      it 'filters by sequence_id' do
        expected_task = VCAP::CloudController::TaskModel.make(app: app_model)
        VCAP::CloudController::TaskModel.make(app: app_model)

        query = { sequence_ids: expected_task.sequence_id }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = "page=1&per_page=50&sequence_ids=#{expected_task.sequence_id}"

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end
    end
  end

  describe 'POST /v3/apps/:guid/tasks' do
    it 'creates a task for an app with an assigned current droplet' do
      body = {
        name:                  'best task ever',
        command:               'be rake && true',
        environment_variables: { unicorn: 'magic' },
        memory_in_mb:          1234,
      }

      post "/v3/apps/#{app_model.guid}/tasks", body, developer_headers

      parsed_response = MultiJson.load(last_response.body)
      guid            = parsed_response['guid']
      sequence_id     = parsed_response['sequence_id']

      expected_response = {
        'guid'                  => guid,
        'sequence_id'           => sequence_id,
        'name'                  => 'best task ever',
        'command'               => 'be rake && true',
        'state'                 => 'RUNNING',
        'memory_in_mb'          => 1234,
        'environment_variables' => { 'unicorn' => 'magic' },
        'result'                => {
          'failure_reason' => nil
        },
        'droplet_guid'          => droplet.guid,
        'created_at'            => iso8601,
        'updated_at'            => iso8601,
        'links'                 => {
          'self' => {
            'href' => "/v3/tasks/#{guid}"
          },
          'app' => {
            'href' => "/v3/apps/#{app_model.guid}"
          },
          'droplet' => {
            'href' => "/v3/droplets/#{droplet.guid}"
          }
        }
      }

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)
      expect(VCAP::CloudController::TaskModel.find(guid: guid)).to be_present
    end

    context 'when requesting a specific droplet' do
      let(:non_assigned_droplet) do
        VCAP::CloudController::DropletModel.make(
          app_guid:     app_model.guid,
          state:        VCAP::CloudController::DropletModel::STAGED_STATE,
          droplet_hash: 'some-droplet-hash'
        )
      end

      it 'uses the requested droplet' do
        body = {
          name:                  'best task ever',
          command:               'be rake && true',
          environment_variables: { unicorn: 'magic' },
          memory_in_mb:          1234,
          droplet_guid:          non_assigned_droplet.guid
        }

        post "/v3/apps/#{app_model.guid}/tasks", body, developer_headers

        parsed_response = MultiJson.load(last_response.body)
        guid            = parsed_response['guid']

        expect(last_response.status).to eq(202)
        expect(parsed_response['droplet_guid']).to eq(non_assigned_droplet.guid)
        expect(parsed_response['links']['droplet']['href']).to eq("/v3/droplets/#{non_assigned_droplet.guid}")
        expect(VCAP::CloudController::TaskModel.find(guid: guid)).to be_present
      end
    end
  end
end
