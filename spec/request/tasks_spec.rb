ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'

describe 'Tasks' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config     = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

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

  describe 'POST /v3/apps/:guid/tasks' do
    it 'creates a task for an app with an assigned current droplet' do
      body = {
        name: 'best task ever',
        command: 'be rake && true',
        environment_variables: {
          unicorn: 'magic'
        },
        memory_in_mb: 1234,
      }

      post "/v3/apps/#{app_model.guid}/tasks", body, developer_headers

      guid = VCAP::CloudController::TaskModel.last.guid

      expected_response = {
        'guid'                  => guid,
        'name'                  => 'best task ever',
        'command'               => 'be rake && true',
        'state'                 => 'RUNNING',
        'memory_in_mb'          => 1234,
        'environment_variables' => { 'unicorn' => 'magic' },
        'result'                => {
          'failure_reason' => nil
        },
        'links'                 => {
          'self'    => {
            'href' => "/v3/tasks/#{guid}"
          },
          'app'     => {
            'href' => "/v3/apps/#{app_model.guid}"
          },
          'droplet' => {
            'href' => "/v3/droplets/#{droplet.guid}"
          }
        }
      }

      parsed_response = JSON.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make(
        name: 'task',
        command: 'echo task',
        app_guid: app_model.guid,
        droplet: app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb: 5,
      )
      task_guid = task.guid

      get "/v3/tasks/#{task_guid}", nil, developer_headers

      expected_response = {
        'guid'                  => task_guid,
        'name'                  => 'task',
        'command'               => 'echo task',
        'state'                 => 'RUNNING',
        'memory_in_mb'          => 5,
        'environment_variables' => { 'unicorn' => 'magic' },
        'result'                => {
          'failure_reason' => nil
        },
        'links'                 => {
          'self'    => {
            'href' => "/v3/tasks/#{task_guid}"
          },
          'app'     => {
            'href' => "/v3/apps/#{app_model.guid}"
          },
          'droplet' => {
            'href' => "/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }

      parsed_response = JSON.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/apps/:guid/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make(
        name:         'task',
        command:      'echo task',
        app:          app_model,
        droplet:      app_model.droplet,
        environment_variables: { unicorn: 'magic' },
        memory_in_mb: 5,
      )
      guid = task.guid

      get "/v3/apps/#{app_model.guid}/tasks/#{guid}", nil, developer_headers

      expected_response = {
        'guid'                  => guid,
        'name'                  => 'task',
        'command'               => 'echo task',
        'state'                 => 'RUNNING',
        'memory_in_mb'          => 5,
        'environment_variables' => { 'unicorn' => 'magic' },
        'result'                => {
          'failure_reason' => nil
        },
        'links'                 => {
          'self'    => {
            'href' => "/v3/tasks/#{guid}"
          },
          'app'     => {
            'href' => "/v3/apps/#{app_model.guid}"
          },
          'droplet' => {
            'href' => "/v3/droplets/#{app_model.droplet.guid}"
          }
        }
      }

      parsed_response = JSON.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
