require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Tasks' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:user) { make_developer_for_space(space) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:droplet) do
    VCAP::CloudController::DropletModel.make(
      app_guid: app_model.guid,
      state:    VCAP::CloudController::DropletModel::STAGED_STATE,
    )
  end
  let(:developer_headers) { headers_for(user, email: user_email, user_name: user_name) }
  let(:user_email) { 'user@email.example.com' }
  let(:user_name) { 'Task McNamara' }
  let(:bbs_task_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient) }

  before do
    VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: true, error_message: nil)
    app_model.droplet = droplet
    app_model.save
  end

  describe 'GET /v3/tasks' do
    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::TaskModel }
      let(:headers) { admin_headers }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/tasks?#{filters}", nil, headers }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/tasks' }
      let(:message) { VCAP::CloudController::TasksListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        [
          :app_guid,
          :sequence_ids
        ]
      end
      let(:params) do
        {
          page:   '2',
          per_page:   '10',
          order_by:   'updated_at',
          guids:   'foo,bar',
          app_guids: 'foo,bar',
          space_guids: 'test',
          names: ['foo', 'bar'],
          states:  ['test', 'foo'],
          organization_guids: 'foo,bar',
          label_selector:   'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/tasks' }
      let(:message) { VCAP::CloudController::TasksListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        [
          :space_guids,
          :app_guids,
          :organization_guids
        ]
      end
      let(:params) do
        {
          states: ['foo', 'bar'],
          guids: ['foo', 'bar'],
          names: ['foo', 'bar'],
          app_guid: app_model.guid,
          sequence_ids: '1,2',
          page:   '2',
          per_page:   '10',
          order_by:   'updated_at',
          label_selector:   'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it 'returns a paginated list of tasks' do
      task1 = VCAP::CloudController::TaskModel.make(
        name:         'task one',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 5,
        disk_in_mb:   10,
      )
      task2 = VCAP::CloudController::TaskModel.make(
        name:         'task two',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 100,
        disk_in_mb:   500,
      )
      VCAP::CloudController::TaskModel.make(
        app_guid: app_model.guid,
        droplet:  app_model.droplet,
      )

      get '/v3/tasks?per_page=2', nil, developer_headers

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
        'pagination' => {
          'total_results' => 3,
          'total_pages'   => 2,
          'first'         => { 'href' => "#{link_prefix}/v3/tasks?page=1&per_page=2" },
          'last'          => { 'href' => "#{link_prefix}/v3/tasks?page=2&per_page=2" },
          'next'          => { 'href' => "#{link_prefix}/v3/tasks?page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'         => task1.guid,
            'sequence_id'  => task1.sequence_id,
            'name'         => 'task one',
            'state'        => 'RUNNING',
            'memory_in_mb' => 5,
            'disk_in_mb'   => 10,
            'result'       => {
              'failure_reason' => nil
            },
            'droplet_guid' => task1.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at'   => iso8601,
            'updated_at'   => iso8601,
            'links'        => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                'method' => 'POST',
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          },
          {
            'guid'         => task2.guid,
            'sequence_id'  => task2.sequence_id,
            'name'         => 'task two',
            'state'        => 'RUNNING',
            'memory_in_mb' => 100,
            'disk_in_mb'   => 500,
            'result'       => {
              'failure_reason' => nil
            },
            'droplet_guid' => task2.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at'   => iso8601,
            'updated_at'   => iso8601,
            'links'        => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                'method' => 'POST',
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          }
        ]
      })
    end

    describe 'filtering' do
      it 'returns a paginated list of tasks' do
        task1 = VCAP::CloudController::TaskModel.make(
          name:         'task one',
          command:      'echo task',
          app_guid:     app_model.guid,
          droplet:      app_model.droplet,
          memory_in_mb: 5,
          state:        VCAP::CloudController::TaskModel::SUCCEEDED_STATE,
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
        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gel', task: task1)
        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gunnison', task: task2)

        query = {
          app_guids:          app_model.guid,
          names:              'task one',
          organization_guids: app_model.organization.guid,
          space_guids:        app_model.space.guid,
          states:             'SUCCEEDED',
          label_selector:     'boomerang',
        }

        get "/v3/tasks?#{query.to_query}", nil, developer_headers

        expected_query = "app_guids=#{app_model.guid}&label_selector=boomerang&names=task+one" \
                         "&organization_guids=#{app_model.organization.guid}" \
                         "&page=1&per_page=50&space_guids=#{app_model.space.guid}&states=SUCCEEDED"

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to eq([task1.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "#{link_prefix}/v3/tasks?#{expected_query}" },
            'last'          => { 'href' => "#{link_prefix}/v3/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end

      it 'filters by label selectors' do
        task1 = VCAP::CloudController::TaskModel.make(
          name:         'task one',
          command:      'echo task',
          app_guid:     app_model.guid,
          droplet:      app_model.droplet,
          memory_in_mb: 5,
          state:        VCAP::CloudController::TaskModel::SUCCEEDED_STATE,
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

        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gel', task: task1)

        get '/v3/tasks?label_selector=boomerang=gel', {}, developer_headers

        expected_pagination = {
            'total_results' => 1,
            'total_pages'   => 1,
            'first'         => { 'href' => "#{link_prefix}/v3/tasks?label_selector=boomerang%3Dgel&page=1&per_page=50" },
            'last'          => { 'href' => "#{link_prefix}/v3/tasks?label_selector=boomerang%3Dgel&page=1&per_page=50" },
            'next'          => nil,
            'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200), last_response.body
        expect(parsed_response['resources'].count).to eq(1)
        expect(parsed_response['resources'][0]['guid']).to eq(task1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  describe 'GET /v3/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make(
        name:         'task',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 5,
        disk_in_mb:   50,
      )
      task_guid = task.guid

      get "/v3/tasks/#{task_guid}", nil, developer_headers

      expected_response = {
        'guid'         => task_guid,
        'sequence_id'  => task.sequence_id,
        'name'         => 'task',
        'command'      => 'echo task',
        'state'        => 'RUNNING',
        'memory_in_mb' => 5,
        'disk_in_mb'   => 50,
        'result'       => {
          'failure_reason' => nil
        },
        'droplet_guid' => task.droplet.guid,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'metadata' => { 'labels' => {}, 'annotations' => {} },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}/actions/cancel",
            'method' => 'POST',
          },
          'droplet' => {
            'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'excludes information for auditors' do
      task = VCAP::CloudController::TaskModel.make(
        name:         'task',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 5,
      )
      task_guid = task.guid

      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/tasks/#{task_guid}", nil, headers_for(auditor)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).not_to have_key('command')
    end
  end

  describe 'PUT /v3/tasks/:guid/cancel (deprecated)' do
    before do
      CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
      allow(bbs_task_client).to receive(:cancel_task)
    end

    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_model.guid

      put "/v3/tasks/#{task.guid}/cancel", nil, developer_headers

      expect(last_response.status).to eq(202)
      parsed_body = JSON.parse(last_response.body)
      expect(parsed_body['guid']).to eq(task.guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('CANCELING')
      expect(parsed_body['result']).to eq({ 'failure_reason' => nil })

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.task.cancel',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             app_model.guid,
        actee_type:        'app',
        actee_name:        app_model.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['task_guid']).to eq(task.guid)
    end
  end

  describe 'PATCH /v3/tasks/:guid' do
    let(:task) { VCAP::CloudController::TaskModel.make(
      name: 'task',
      command: 'echo task',
      app_guid: app_model.guid,
      droplet_guid: app_model.droplet.guid,
    disk_in_mb: 50,
    memory_in_mb: 5)
    }
    let(:request_body) do
      {
        metadata: {
          labels: {
            potato: 'yam'
          },
          annotations: {
            potato: 'idaho'
          }
        }
      }.to_json
    end
    let(:headers) { admin_headers_for(user) }
    let(:task_guid) { task.guid }

    it "updates the task's metadata" do
      patch "/v3/tasks/#{task_guid}", request_body, headers

      expect(last_response.status).to eq(200)
      expected_response = {
        'guid'         => task.guid,
        'sequence_id'  => task.sequence_id,
        'name'         => 'task',
        'command'      => 'echo task',
        'state'        => 'RUNNING',
        'memory_in_mb' => 5,
        'disk_in_mb'   => 50,
        'result'       => {
          'failure_reason' => nil
        },
        'droplet_guid' => task.droplet.guid,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'metadata' =>  {
          'labels' => {
            'potato' => 'yam'
          },
          'annotations' => {
            'potato' => 'idaho'
          },
        },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}/actions/cancel",
            'method' => 'POST',
          },
          'droplet' => {
            'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'POST /v3/tasks/:guid/actions/cancel' do
    before do
      CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
      allow(bbs_task_client).to receive(:cancel_task)
    end
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_model.guid

      post "/v3/tasks/#{task.guid}/actions/cancel", nil, developer_headers

      expect(last_response.status).to eq(202)
      parsed_body = JSON.parse(last_response.body)
      expect(parsed_body['guid']).to eq(task.guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('CANCELING')
      expect(parsed_body['result']).to eq({ 'failure_reason' => nil })

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.task.cancel',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             app_model.guid,
        actee_type:        'app',
        actee_name:        app_model.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['task_guid']).to eq(task.guid)
    end
  end

  describe 'GET /v3/apps/:guid/tasks' do
    it 'returns a paginated list of tasks' do
      task1 = VCAP::CloudController::TaskModel.make(
        name:         'task one',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 5,
        disk_in_mb:   50,
      )
      task2 = VCAP::CloudController::TaskModel.make(
        name:         'task two',
        command:      'echo task',
        app_guid:     app_model.guid,
        droplet:      app_model.droplet,
        memory_in_mb: 100,
        disk_in_mb:   500,
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
            'first'         => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=1&per_page=2" },
            'last'          => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
            'next'          => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
            'previous'      => nil,
          },
          'resources' => [
            {
              'guid'         => task1.guid,
              'sequence_id'  => task1.sequence_id,
              'name'         => 'task one',
              'command'      => 'echo task',
              'state'        => 'RUNNING',
              'memory_in_mb' => 5,
              'disk_in_mb'   => 50,
              'result'       => {
                'failure_reason' => nil
              },
              'droplet_guid' => task1.droplet.guid,
              'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'created_at'   => iso8601,
              'updated_at'   => iso8601,
              'links'        => {
                'self' => {
                  'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                },
                'cancel' => {
                  'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                  'method' => 'POST',
                },
                'droplet' => {
                  'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
                }
              }
            },
            {
              'guid'         => task2.guid,
              'sequence_id'  => task2.sequence_id,
              'name'         => 'task two',
              'command'      => 'echo task',
              'state'        => 'RUNNING',
              'memory_in_mb' => 100,
              'disk_in_mb'   => 500,
              'result'       => {
                'failure_reason' => nil
              },
              'droplet_guid' => task2.droplet.guid,
              'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'created_at'   => iso8601,
              'updated_at'   => iso8601,
              'links'        => {
                'self' => {
                  'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                },
                'cancel' => {
                  'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                  'method' => 'POST',
                },
                'droplet' => {
                  'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
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
          name:         'task one',
          command:      'echo task',
          app_guid:     app_model.guid,
          droplet:      app_model.droplet,
          memory_in_mb: 5,
        )

        get "/v3/apps/#{app_model.guid}/tasks", nil, headers_for(make_auditor_for_space(space))

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'][0]).not_to have_key('command')
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
            'first'         => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
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
            'first'         => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
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
            'first'         => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last'          => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next'          => nil,
            'previous'      => nil,
          }
        )
      end

      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::TaskModel }
        let(:additional_resource_params) { { app: app_model } }
        let(:headers) { admin_headers }
        let(:api_call) do
          lambda { |headers, filters| get "/v3/apps/#{app_model.guid}/tasks?#{filters}", nil, headers }
        end
      end
    end
  end

  describe 'POST /v3/apps/:guid/tasks' do
    let(:body) do {
      name:         'best task ever',
      command:      'be rake && true',
      memory_in_mb: 1234,
      disk_in_mb:   1000,
      metadata: {
        labels: {
          bananas: 'gros_michel',
        },
        annotations: {
          'wombats' => 'althea',
        }
      },
    }
    end
    before do
      CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
      allow(bbs_task_client).to receive(:desire_task)
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).and_return('http://example.com/somewhere/else')
      allow_any_instance_of(VCAP::CloudController::Diego::TaskRecipeBuilder).to receive(:build_app_task)
    end

    it 'creates a task for an app with an assigned current droplet' do
      post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

      parsed_response = MultiJson.load(last_response.body)
      guid            = parsed_response['guid']
      sequence_id     = parsed_response['sequence_id']

      expected_response = {
        'guid'         => guid,
        'sequence_id'  => sequence_id,
        'name'         => 'best task ever',
        'command'      => 'be rake && true',
        'state'        => 'RUNNING',
        'memory_in_mb' => 1234,
        'disk_in_mb'   => 1000,
        'result'       => {
          'failure_reason' => nil
        },
        'droplet_guid' => droplet.guid,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'metadata' => { 'labels' => { 'bananas' => 'gros_michel', },
          'annotations' => { 'wombats' => 'althea' } },
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links'        => {
          'self' => {
            'href' => "#{link_prefix}/v3/tasks/#{guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/tasks/#{guid}/actions/cancel",
            'method' => 'POST',
          },
          'droplet' => {
            'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}"
          }
        }
      }

      expect(last_response.status).to eq(202), last_response.body
      expect(parsed_response).to be_a_response_like(expected_response)
      expect(VCAP::CloudController::TaskModel.find(guid: guid)).to be_present

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.task.create',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             app_model.guid,
        actee_type:        'app',
        actee_name:        app_model.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata).to eq({
        'task_guid' => guid,
        'request'   => {
          'name'         => 'best task ever',
          'command'      => '[PRIVATE DATA HIDDEN]',
          'memory_in_mb' => 1234,
        }
      })
    end

    context 'when requesting a specific droplet' do
      let(:non_assigned_droplet) do
        VCAP::CloudController::DropletModel.make(
          app_guid: app_model.guid,
          state:    VCAP::CloudController::DropletModel::STAGED_STATE,
        )
      end

      it 'uses the requested droplet' do
        body = {
          name:         'best task ever',
          command:      'be rake && true',
          memory_in_mb: 1234,
          droplet_guid: non_assigned_droplet.guid
        }

        post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

        parsed_response = MultiJson.load(last_response.body)
        guid            = parsed_response['guid']

        expect(last_response.status).to eq(202)
        expect(parsed_response['droplet_guid']).to eq(non_assigned_droplet.guid)
        expect(parsed_response['links']['droplet']['href']).to eq("#{link_prefix}/v3/droplets/#{non_assigned_droplet.guid}")
        expect(VCAP::CloudController::TaskModel.find(guid: guid)).to be_present
      end
    end

    context 'when the client specifies a template' do
      let(:process) { VCAP::CloudController::ProcessModel.make(app: app_model, command: 'start') }
      it 'uses the command from the template process' do
        body = {
          name:         'best task ever',
          template: {
            process: {
              guid: process.guid
            }
          },
          memory_in_mb: 1234,
          disk_in_mb:   1000,
        }

        post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

        guid            = parsed_response['guid']
        sequence_id     = parsed_response['sequence_id']

        expected_response = {
          'guid'         => guid,
          'sequence_id'  => sequence_id,
          'name'         => 'best task ever',
          'command'      => process.command,
          'state'        => 'RUNNING',
          'memory_in_mb' => 1234,
          'disk_in_mb'   => 1000,
          'result'       => {
            'failure_reason' => nil
          },
          'droplet_guid' => droplet.guid,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'created_at'   => iso8601,
          'updated_at'   => iso8601,
          'links'        => {
            'self' => {
              'href' => "#{link_prefix}/v3/tasks/#{guid}"
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
            },
            'cancel' => {
              'href' => "#{link_prefix}/v3/tasks/#{guid}/actions/cancel",
              'method' => 'POST',
            },
            'droplet' => {
              'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}"
            }
          }
        }

        expect(last_response.status).to eq(202)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    context 'telemetry' do
      it 'should log the required fields when the task is created' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-task' => {
              'api-version' => 'v3',
              'app-id' => Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => Digest::SHA256.hexdigest(user.guid),
            }
          }

          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(JSON.generate(expected_json))
          post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

          expect(last_response.status).to eq(202)
        end
      end
    end
  end
end
