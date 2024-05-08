require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Tasks' do
  let(:org_quota_definition) { VCAP::CloudController::QuotaDefinition.make(log_rate_limit: org_log_rate_limit) }
  let(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, log_rate_limit: space_log_rate_limit) }
  let(:space_log_rate_limit) { -1 }
  let(:org_log_rate_limit) { -1 }
  let(:task_log_rate_limit_in_bytes_per_second) { -1 }
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make(quota_definition: org_quota_definition) }
  let(:space) { VCAP::CloudController::Space.make(space_quota_definition: space_quota_definition, organization: org) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:droplet) do
    VCAP::CloudController::DropletModel.make(
      app_guid: app_model.guid,
      state: VCAP::CloudController::DropletModel::STAGED_STATE
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
      let(:user) { make_developer_for_space(space) }
      let(:resource_klass) { VCAP::CloudController::TaskModel }
      let(:headers) { admin_headers }
      let(:api_call) do
        ->(headers, filters) { get "/v3/tasks?#{filters}", nil, headers }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:user) { make_developer_for_space(space) }
      let(:request) { 'v3/tasks' }
      let(:message) { VCAP::CloudController::TasksListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        %i[
          app_guid
          sequence_ids
        ]
      end
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          guids: 'foo,bar',
          app_guids: 'foo,bar',
          space_guids: 'test',
          names: %w[foo bar],
          states: %w[test foo],
          organization_guids: 'foo,bar',
          label_selector: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:user) { make_developer_for_space(space) }
      let(:request) { 'v3/tasks' }
      let(:message) { VCAP::CloudController::TasksListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        %i[
          space_guids
          app_guids
          organization_guids
        ]
      end
      let(:params) do
        {
          states: %w[foo bar],
          guids: %w[foo bar],
          names: %w[foo bar],
          app_guid: app_model.guid,
          sequence_ids: '1,2',
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end
    end

    context 'pagination' do
      let(:user) { make_developer_for_space(space) }

      it 'returns a paginated list of tasks' do
        task1 = VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          disk_in_mb: 10,
          log_rate_limit: 20
        )
        task2 = VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 100,
          disk_in_mb: 500,
          log_rate_limit: 1024
        )
        VCAP::CloudController::TaskModel.make(
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )

        get '/v3/tasks?per_page=2', nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like({
                                                        'pagination' => {
                                                          'total_results' => 3,
                                                          'total_pages' => 2,
                                                          'first' => { 'href' => "#{link_prefix}/v3/tasks?page=1&per_page=2" },
                                                          'last' => { 'href' => "#{link_prefix}/v3/tasks?page=2&per_page=2" },
                                                          'next' => { 'href' => "#{link_prefix}/v3/tasks?page=2&per_page=2" },
                                                          'previous' => nil
                                                        },
                                                        'resources' => [
                                                          {
                                                            'guid' => task1.guid,
                                                            'sequence_id' => task1.sequence_id,
                                                            'name' => 'task one',
                                                            'state' => 'RUNNING',
                                                            'memory_in_mb' => 5,
                                                            'disk_in_mb' => 10,
                                                            'log_rate_limit_in_bytes_per_second' => 20,
                                                            'result' => {
                                                              'failure_reason' => nil
                                                            },
                                                            'droplet_guid' => task1.droplet.guid,
                                                            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                                                            'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                            'created_at' => iso8601,
                                                            'updated_at' => iso8601,
                                                            'links' => {
                                                              'self' => {
                                                                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
                                                              },
                                                              'app' => {
                                                                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                              },
                                                              'cancel' => {
                                                                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                                                                'method' => 'POST'
                                                              },
                                                              'droplet' => {
                                                                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
                                                              }
                                                            }
                                                          },
                                                          {
                                                            'guid' => task2.guid,
                                                            'sequence_id' => task2.sequence_id,
                                                            'name' => 'task two',
                                                            'state' => 'RUNNING',
                                                            'memory_in_mb' => 100,
                                                            'disk_in_mb' => 500,
                                                            'log_rate_limit_in_bytes_per_second' => 1024,
                                                            'result' => {
                                                              'failure_reason' => nil
                                                            },
                                                            'droplet_guid' => task2.droplet.guid,
                                                            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                                                            'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                            'created_at' => iso8601,
                                                            'updated_at' => iso8601,
                                                            'links' => {
                                                              'self' => {
                                                                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
                                                              },
                                                              'app' => {
                                                                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                              },
                                                              'cancel' => {
                                                                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                                                                'method' => 'POST'
                                                              },
                                                              'droplet' => {
                                                                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
                                                              }
                                                            }
                                                          }
                                                        ]
                                                      })
      end
    end

    it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS do
      let(:api_call) { ->(user_headers) { get '/v3/tasks', nil, user_headers } }
      let(:task1) do
        VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )
      end

      let(:task2) do
        VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          disk_in_mb: 10,
          log_rate_limit: 20
        )
      end

      let(:expected_response) do
        [
          {
            'guid' => task1.guid,
            'sequence_id' => task1.sequence_id,
            'name' => 'task one',
            'state' => 'RUNNING',
            'memory_in_mb' => 256,
            'disk_in_mb' => nil,
            'log_rate_limit_in_bytes_per_second' => -1,
            'result' => {
              'failure_reason' => nil
            },
            'droplet_guid' => task1.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                'method' => 'POST'
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          },
          {
            'guid' => task2.guid,
            'sequence_id' => task2.sequence_id,
            'name' => 'task two',
            'state' => 'RUNNING',
            'memory_in_mb' => 5,
            'disk_in_mb' => 10,
            'log_rate_limit_in_bytes_per_second' => 20,
            'result' => {
              'failure_reason' => nil
            },
            'droplet_guid' => task2.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                'method' => 'POST'
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          }
        ]
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: expected_response)
        h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
          code: 200,
          response_objects: []
        }
        h
      end
    end

    describe 'filtering' do
      let(:user) { make_developer_for_space(space) }

      it 'returns a paginated list of tasks' do
        task1 = VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE
        )
        task2 = VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 100
        )
        VCAP::CloudController::TaskModel.make(
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )
        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gel', task: task1)
        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gunnison', task: task2)

        query = {
          app_guids: app_model.guid,
          names: 'task one',
          organization_guids: app_model.organization.guid,
          space_guids: app_model.space.guid,
          states: 'SUCCEEDED',
          label_selector: 'boomerang'
        }

        get "/v3/tasks?#{query.to_query}", nil, developer_headers

        expected_query = "app_guids=#{app_model.guid}&label_selector=boomerang&names=task+one" \
                         "&organization_guids=#{app_model.organization.guid}" \
                         "&page=1&per_page=50&space_guids=#{app_model.space.guid}&states=SUCCEEDED"

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to eq([task1.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/tasks?#{expected_query}" },
            'last' => { 'href' => "#{link_prefix}/v3/tasks?#{expected_query}" },
            'next' => nil,
            'previous' => nil
          }
        )
      end

      it 'filters by label selectors' do
        task1 = VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE
        )
        VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 100
        )
        VCAP::CloudController::TaskModel.make(
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )

        VCAP::CloudController::TaskLabelModel.make(key_name: 'boomerang', value: 'gel', task: task1)

        get '/v3/tasks?label_selector=boomerang=gel', {}, developer_headers

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/tasks?label_selector=boomerang%3Dgel&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/tasks?label_selector=boomerang%3Dgel&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200), last_response.body
        expect(parsed_response['resources'].count).to eq(1)
        expect(parsed_response['resources'][0]['guid']).to eq(task1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  describe 'GET /v3/tasks/:guid' do
    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:task) do
        VCAP::CloudController::TaskModel.make(
          name: 'task',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          disk_in_mb: 50,
          log_rate_limit: 64
        )
      end
      let(:api_call) { ->(user_headers) { get "/v3/tasks/#{task.guid}", nil, user_headers } }
      let(:expected_response) do
        {
          'guid' => task.guid,
          'sequence_id' => task.sequence_id,
          'name' => 'task',
          'state' => 'RUNNING',
          'memory_in_mb' => 5,
          'disk_in_mb' => 50,
          'log_rate_limit_in_bytes_per_second' => 64,
          'result' => {
            'failure_reason' => nil
          },
          'droplet_guid' => task.droplet.guid,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/tasks/#{task.guid}"
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
            },
            'cancel' => {
              'href' => "#{link_prefix}/v3/tasks/#{task.guid}/actions/cancel",
              'method' => 'POST'
            },
            'droplet' => {
              'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
            }
          }
        }
      end
      let(:expected_response_with_command) { expected_response.merge({ 'command' => 'echo task' }) }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_object: expected_response)
        h['admin'] = h['admin_read_only'] = h['space_developer'] = { code: 200, response_object: expected_response_with_command }
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
        h
      end
    end
  end

  describe 'PUT /v3/tasks/:guid/cancel (deprecated)' do
    let(:user) { make_developer_for_space(space) }

    before do
      CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
      allow(bbs_task_client).to receive(:cancel_task)
    end

    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_model.guid

      put "/v3/tasks/#{task.guid}/cancel", nil, developer_headers

      expect(last_response.status).to eq(202)
      parsed_body = Oj.load(last_response.body)
      expect(parsed_body['guid']).to eq(task.guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('CANCELING')
      expect(parsed_body['result']).to eq({ 'failure_reason' => nil })

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.app.task.cancel',
                                        actor: user.guid,
                                        actor_type: 'user',
                                        actor_name: user_email,
                                        actor_username: user_name,
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: app_model.name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['task_guid']).to eq(task.guid)
    end
  end

  describe 'PATCH /v3/tasks/:guid' do
    let(:user) { make_developer_for_space(space) }
    let(:task) do
      VCAP::CloudController::TaskModel.make(
        name: 'task',
        command: 'echo task',
        app_guid: app_model.guid,
        droplet_guid: app_model.droplet.guid,
        disk_in_mb: 50,
        memory_in_mb: 5,
        log_rate_limit: 10
      )
    end
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
        'guid' => task.guid,
        'sequence_id' => task.sequence_id,
        'name' => 'task',
        'command' => 'echo task',
        'state' => 'RUNNING',
        'memory_in_mb' => 5,
        'disk_in_mb' => 50,
        'log_rate_limit_in_bytes_per_second' => 10,
        'result' => {
          'failure_reason' => nil
        },
        'droplet_guid' => task.droplet.guid,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'metadata' => {
          'labels' => {
            'potato' => 'yam'
          },
          'annotations' => {
            'potato' => 'idaho'
          }
        },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/tasks/#{task_guid}/actions/cancel",
            'method' => 'POST'
          },
          'droplet' => {
            'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'permissions' do
      let(:api_call) { ->(headers) { patch "/v3/tasks/#{task_guid}", request_body, headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
        %w[admin space_developer].each { |r| h[r] = { code: 200 } }
        h
      end

      before do
        space.remove_developer(user)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end

  describe 'POST /v3/tasks/:guid/actions/cancel' do
    let(:task) { VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_model.guid }
    let(:api_call) { ->(user_headers) { post "/v3/tasks/#{task.guid}/actions/cancel", nil, user_headers } }
    let(:expected_response) do
      {
        guid: task.guid,
        sequence_id: task.sequence_id,
        name: 'task',
        command: 'echo task',
        state: 'CANCELING',
        memory_in_mb: 256,
        disk_in_mb: nil,
        log_rate_limit_in_bytes_per_second: -1,
        result: {
          failure_reason: nil
        },
        droplet_guid: task.droplet.guid,
        metadata: {
          labels: {},
          annotations: {}
        },
        created_at: iso8601,
        updated_at: iso8601,
        relationships: {
          app: {
            data: {
              guid: app_model.guid
            }
          }
        },
        links: {
          self: {
            href: %r{#{link_prefix}/v3/tasks/#{task.guid}}
          },
          app: {
            href: "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          cancel: {
            href: %r{#{link_prefix}/v3/tasks/#{task.guid}/actions/cancel},
            method: 'POST'
          },
          droplet: {
            href: %r{#{link_prefix}/v3/droplets/#{task.droplet.guid}}
          }
        }
      }
    end
    let(:expected_codes_and_responses) do
      h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
      h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
      h['admin'] = h['space_developer'] = h['space_supporter'] = {
        code: 202,
        response_object: expected_response
      }
      h
    end

    before do
      CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
      allow(bbs_task_client).to receive(:cancel_task)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when organization is suspended' do
      let(:expected_codes_and_responses) do
        h = super()
        %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
        h
      end

      before do
        org.update(status: VCAP::CloudController::Organization::SUSPENDED)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/apps/:guid/tasks' do
    context 'pagination' do
      let(:user) { make_developer_for_space(space) }

      it 'returns a paginated list of tasks' do
        task1 = VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          disk_in_mb: 50,
          log_rate_limit: 64
        )
        task2 = VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 100,
          disk_in_mb: 500,
          log_rate_limit: 256
        )
        VCAP::CloudController::TaskModel.make(
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )

        get "/v3/apps/#{app_model.guid}/tasks?per_page=2", nil, developer_headers

        expected_response =
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=1&per_page=2" },
              'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
              'next' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?page=2&per_page=2" },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => task1.guid,
                'sequence_id' => task1.sequence_id,
                'name' => 'task one',
                'command' => 'echo task',
                'state' => 'RUNNING',
                'memory_in_mb' => 5,
                'disk_in_mb' => 50,
                'log_rate_limit_in_bytes_per_second' => 64,
                'result' => {
                  'failure_reason' => nil
                },
                'droplet_guid' => task1.droplet.guid,
                'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
                  },
                  'app' => {
                    'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                  },
                  'cancel' => {
                    'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                    'method' => 'POST'
                  },
                  'droplet' => {
                    'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
                  }
                }
              },
              {
                'guid' => task2.guid,
                'sequence_id' => task2.sequence_id,
                'name' => 'task two',
                'command' => 'echo task',
                'state' => 'RUNNING',
                'memory_in_mb' => 100,
                'disk_in_mb' => 500,
                'log_rate_limit_in_bytes_per_second' => 256,
                'result' => {
                  'failure_reason' => nil
                },
                'droplet_guid' => task2.droplet.guid,
                'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
                  },
                  'app' => {
                    'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                  },
                  'cancel' => {
                    'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                    'method' => 'POST'
                  },
                  'droplet' => {
                    'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
                  }
                }
              }
            ]
          }

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/tasks", nil, user_headers } }
      let(:task1) do
        VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet
        )
      end

      let(:task2) do
        VCAP::CloudController::TaskModel.make(
          name: 'task two',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5,
          disk_in_mb: 10
        )
      end

      let(:expected_response) do
        [
          {
            'guid' => task1.guid,
            'sequence_id' => task1.sequence_id,
            'name' => 'task one',
            'state' => 'RUNNING',
            'memory_in_mb' => 256,
            'disk_in_mb' => nil,
            'log_rate_limit_in_bytes_per_second' => -1,
            'result' => {
              'failure_reason' => nil
            },
            'droplet_guid' => task1.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task1.guid}/actions/cancel",
                'method' => 'POST'
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          },
          {
            'guid' => task2.guid,
            'sequence_id' => task2.sequence_id,
            'name' => 'task two',
            'state' => 'RUNNING',
            'memory_in_mb' => 5,
            'disk_in_mb' => 10,
            'log_rate_limit_in_bytes_per_second' => -1,
            'result' => {
              'failure_reason' => nil
            },
            'droplet_guid' => task2.droplet.guid,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}"
              },
              'app' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
              },
              'cancel' => {
                'href' => "#{link_prefix}/v3/tasks/#{task2.guid}/actions/cancel",
                'method' => 'POST'
              },
              'droplet' => {
                'href' => "#{link_prefix}/v3/droplets/#{app_model.droplet.guid}"
              }
            }
          }
        ]
      end
      let(:expected_response_with_command) { expected_response.map { |task| task.merge({ 'command' => 'echo task' }) } }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: expected_response)
        h['admin'] = h['admin_read_only'] = h['space_developer'] = { code: 200, response_objects: expected_response_with_command }
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
        h
      end
    end

    describe 'perms' do
      it 'exlcudes secrets when the user should not see them' do
        VCAP::CloudController::TaskModel.make(
          name: 'task one',
          command: 'echo task',
          app_guid: app_model.guid,
          droplet: app_model.droplet,
          memory_in_mb: 5
        )

        get "/v3/apps/#{app_model.guid}/tasks", nil, headers_for(make_auditor_for_space(space))

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['resources'][0]).not_to have_key('command')
      end
    end

    describe 'filtering' do
      let(:user) { make_developer_for_space(space) }

      it 'filters by name' do
        expected_task = VCAP::CloudController::TaskModel.make(name: 'task one', app: app_model)
        VCAP::CloudController::TaskModel.make(name: 'task two', app: app_model)

        query = { names: 'task one' }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = 'names=task+one&page=1&per_page=50'

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next' => nil,
            'previous' => nil
          }
        )
      end

      it 'filters by state' do
        expected_task = VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE, app: app_model)
        VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::FAILED_STATE, app: app_model)

        query = { states: 'SUCCEEDED' }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = 'page=1&per_page=50&states=SUCCEEDED'

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next' => nil,
            'previous' => nil
          }
        )
      end

      it 'filters by sequence_id' do
        expected_task = VCAP::CloudController::TaskModel.make(app: app_model)
        VCAP::CloudController::TaskModel.make(app: app_model)

        query = { sequence_ids: expected_task.sequence_id }

        get "/v3/apps/#{app_model.guid}/tasks?#{query.to_query}", nil, developer_headers

        expected_query = "page=1&per_page=50&sequence_ids=#{expected_task.sequence_id}"

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to eq([expected_task.guid])
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks?#{expected_query}" },
            'next' => nil,
            'previous' => nil
          }
        )
      end

      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::TaskModel }
        let(:additional_resource_params) { { app: app_model } }
        let(:headers) { admin_headers }
        let(:api_call) do
          ->(headers, filters) { get "/v3/apps/#{app_model.guid}/tasks?#{filters}", nil, headers }
        end
      end
    end
  end

  describe 'POST /v3/apps/:guid/tasks' do
    let(:user) { make_developer_for_space(space) }
    let(:body) do
      {
        name: 'best task ever',
        command: 'be rake && true',
        memory_in_mb: 1234,
        disk_in_mb: 1000,
        log_rate_limit_in_bytes_per_second: task_log_rate_limit_in_bytes_per_second,
        metadata: {
          labels: {
            bananas: 'gros_michel'
          },
          annotations: {
            'wombats' => 'althea'
          }
        }
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

      parsed_response = Oj.load(last_response.body)
      guid            = parsed_response['guid']
      sequence_id     = parsed_response['sequence_id']

      expected_response = {
        'guid' => guid,
        'sequence_id' => sequence_id,
        'name' => 'best task ever',
        'command' => 'be rake && true',
        'state' => 'RUNNING',
        'memory_in_mb' => 1234,
        'disk_in_mb' => 1000,
        'log_rate_limit_in_bytes_per_second' => task_log_rate_limit_in_bytes_per_second,
        'result' => {
          'failure_reason' => nil
        },
        'droplet_guid' => droplet.guid,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'metadata' => { 'labels' => { 'bananas' => 'gros_michel' },
                        'annotations' => { 'wombats' => 'althea' } },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/tasks/#{guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/tasks/#{guid}/actions/cancel",
            'method' => 'POST'
          },
          'droplet' => {
            'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}"
          }
        }
      }

      expect(last_response.status).to eq(202), last_response.body
      expect(parsed_response).to be_a_response_like(expected_response)
      expect(VCAP::CloudController::TaskModel.find(guid:)).to be_present

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.app.task.create',
                                        actor: user.guid,
                                        actor_type: 'user',
                                        actor_name: user_email,
                                        actor_username: user_name,
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: app_model.name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata).to eq({
                                     'task_guid' => guid,
                                     'request' => {
                                       'name' => 'best task ever',
                                       'command' => '[PRIVATE DATA HIDDEN]',
                                       'memory_in_mb' => 1234
                                     }
                                   })
    end

    describe 'log_rate_limit' do
      context 'when the request does not specify a log rate limit' do
        before do
          TestConfig.config[:default_app_log_rate_limit_in_bytes_per_second] = 9876
        end

        it 'the default is applied' do
          post "/v3/apps/#{app_model.guid}/tasks", body.except(:log_rate_limit_in_bytes_per_second).to_json, developer_headers
          expect(last_response.status).to eq(202)
          expect(VCAP::CloudController::TaskModel.last.log_rate_limit).to eq(9876)
        end
      end

      context 'when there are org or space log rate limits' do
        let(:space_log_rate_limit) { 200 }
        let(:org_log_rate_limit) { 201 }

        context 'when the task specifies a rate limit that fits in the quota' do
          let(:task_log_rate_limit_in_bytes_per_second) { 199 }

          it 'succeeds' do
            post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers
            expect(last_response.status).to eq(202)
          end
        end

        context 'when the task specifies unlimited rate limit' do
          let(:task_log_rate_limit_in_bytes_per_second) { -1 }

          it 'returns an error' do
            post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers
            expect(last_response.status).to eq(422)
            expect(last_response).to have_error_message("log_rate_limit cannot be unlimited in organization '#{org.name}'.")
            expect(last_response).to have_error_message("log_rate_limit cannot be unlimited in space '#{space.name}'.")
          end
        end

        context 'when the task specifies a rate limit that does not fit in the quota' do
          let(:task_log_rate_limit_in_bytes_per_second) { 202 }

          context 'fails to fit in space quota' do
            let(:space_log_rate_limit) { 200 }
            let(:org_log_rate_limit) { -1 }

            it 'returns an error' do
              post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers
              expect(last_response.status).to eq(422)
              expect(last_response).to have_error_message('log_rate_limit exceeds space log rate quota')
            end
          end

          context 'fails to fit in org quota' do
            let(:space_log_rate_limit) { -1 }
            let(:org_log_rate_limit) { 200 }

            it 'returns an error' do
              post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers
              expect(last_response.status).to eq(422)
              expect(last_response).to have_error_message('log_rate_limit exceeds organization log rate quota')
            end
          end
        end
      end
    end

    context 'when requesting a specific droplet' do
      let(:non_assigned_droplet) do
        VCAP::CloudController::DropletModel.make(
          app_guid: app_model.guid,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end

      it 'uses the requested droplet' do
        body = {
          name: 'best task ever',
          command: 'be rake && true',
          memory_in_mb: 1234,
          droplet_guid: non_assigned_droplet.guid
        }

        post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

        parsed_response = Oj.load(last_response.body)
        guid            = parsed_response['guid']

        expect(last_response.status).to eq(202)
        expect(parsed_response['droplet_guid']).to eq(non_assigned_droplet.guid)
        expect(parsed_response['links']['droplet']['href']).to eq("#{link_prefix}/v3/droplets/#{non_assigned_droplet.guid}")
        expect(VCAP::CloudController::TaskModel.find(guid:)).to be_present
      end
    end

    context 'when the client specifies a template' do
      let(:process) { VCAP::CloudController::ProcessModel.make(app: app_model, command: 'start') }

      it 'uses the command from the template process' do
        body = {
          name: 'best task ever',
          template: {
            process: {
              guid: process.guid
            }
          },
          memory_in_mb: 1234,
          disk_in_mb: 1000
        }

        post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

        guid            = parsed_response['guid']
        sequence_id     = parsed_response['sequence_id']

        expected_response = {
          'guid' => guid,
          'sequence_id' => sequence_id,
          'name' => 'best task ever',
          'command' => process.command,
          'state' => 'RUNNING',
          'memory_in_mb' => 1234,
          'disk_in_mb' => 1000,
          'log_rate_limit_in_bytes_per_second' => process.log_rate_limit,
          'result' => {
            'failure_reason' => nil
          },
          'droplet_guid' => droplet.guid,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/tasks/#{guid}"
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
            },
            'cancel' => {
              'href' => "#{link_prefix}/v3/tasks/#{guid}/actions/cancel",
              'method' => 'POST'
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
      it 'logs the required fields when the task is created' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-task' => {
              'api-version' => 'v3',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
            }
          }

          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))
          post "/v3/apps/#{app_model.guid}/tasks", body.to_json, developer_headers

          expect(last_response.status).to eq(202)
        end
      end
    end

    context 'permissions' do
      let(:api_call) { ->(headers) { post "/v3/apps/#{app_model.guid}/tasks", body.to_json, headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
        %w[admin space_developer].each { |r| h[r] = { code: 202 } }
        h
      end

      before do
        space.remove_developer(user)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end
end
