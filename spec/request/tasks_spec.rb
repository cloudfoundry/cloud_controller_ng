ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'

describe 'Tasks' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

  let(:space) { VCAP::CloudController::Space.make }
  let!(:org) { space.organization }
  let!(:user) { VCAP::CloudController::User.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let!(:droplet) do
    VCAP::CloudController::DropletModel.make(
      app_guid: app_model.guid,
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      droplet_hash: 'droplet-hash'
    )
  end

  before do
    allow(ApplicationController).to receive(:configuration).and_return(TestConfig.config)
    stub_request(:put, 'http://nsync.service.cf.internal:8787/v1/task').to_return(status: 202)

    VCAP::CloudController::FeatureFlag.make(name: 'task_creation', enabled: true, error_message: nil)

    app_model.droplet = droplet
    app_model.save
  end

  describe 'POST /v3/apps/:guid/tasks' do
    it 'creates a task for an app with an assigned current droplet' do
      body = {
        name: 'best task ever',
        command: 'be rake && true'
      }
      post "/v3/apps/#{app_model.guid}/tasks", body, admin_headers

      expect(last_response.status).to eq(202)
      parsed_body = JSON.load(last_response.body)
      guid = VCAP::CloudController::TaskModel.last.guid

      expect(parsed_body['guid']).to eq(guid)
      expect(parsed_body['name']).to eq('best task ever')
      expect(parsed_body['command']).to eq('be rake && true')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['result']).to eq({ 'message' => nil })

      expect(parsed_body['links']['self']).to eq({ 'href' => "/v3/tasks/#{guid}" })
      expect(parsed_body['links']['app']).to eq({ 'href' => "/v3/apps/#{app_model.guid}" })
      expect(parsed_body['links']['droplet']).to eq({ 'href' => "/v3/droplets/#{droplet.guid}" })
    end
  end

  describe 'GET /v3/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      task = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_model.guid
      task_guid = task.guid

      get "/v3/tasks/#{task_guid}", {}, admin_headers

      expect(last_response.status).to eq(200)
      parsed_body = JSON.load(last_response.body)
      expect(parsed_body['guid']).to eq(task_guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['result']).to eq({ 'message' => nil })
    end
  end

  describe 'GET /v3/apps/:guid/tasks/:guid' do
    it 'returns a json representation of the task with the requested guid' do
      app_guid = app_model.guid
      task = VCAP::CloudController::TaskModel.make name: 'task', command: 'echo task', app_guid: app_guid
      task_guid = task.guid

      get "/v3/apps/#{app_guid}/tasks/#{task_guid}", {}, admin_headers

      expect(last_response.status).to eq(200)
      parsed_body = JSON.load(last_response.body)
      expect(parsed_body['guid']).to eq(task_guid)
      expect(parsed_body['name']).to eq('task')
      expect(parsed_body['command']).to eq('echo task')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['result']).to eq({ 'message' => nil })
    end
  end
end
