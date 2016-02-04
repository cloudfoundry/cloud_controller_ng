ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'

describe 'Route Mappings' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config     = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }

  let(:space) { VCAP::CloudController::Space.make }
  let!(:org) { space.organization }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:process) { VCAP::CloudController::App.make(space: space, app_guid: app_model.guid, type: 'worker') }
  let(:route) { VCAP::CloudController::Route.make(space: space) }
  let!(:developer) { make_developer_for_space(space) }
  let(:developer_headers) do
    headers_for(developer)
  end

  before do
    allow(ApplicationController).to receive(:configuration).and_return(TestConfig.config)
  end

  describe 'POST /v3/apps/:guid/route_mappings' do
    it 'creates a route mapping for a specific process on an app' do
      body = {
        relationships: {
          route:   { guid: route.guid },
          process: { type: process.type }
        }
      }

      post "/v3/apps/#{app_model.guid}/route_mappings", body, developer_headers

      guid = VCAP::CloudController::RouteMappingModel.last.guid

      expected_response = {
        'guid' =>       guid,
        'created_at' => iso8601,
        'updated_at' => nil,

        'links' =>      {
          'self' =>    { 'href' => "/v3/apps/#{app_model.guid}/route_mappings/#{guid}" },
          'app' =>     { 'href' => "/v3/apps/#{app_model.guid}" },
          'route' =>   { 'href' => "/v2/routes/#{route.guid}" },
          'process' => { 'href' => "/v3/apps/#{app_model.guid}/processes/#{process.type}" }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      # verify response
      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)

      # verify mapping
      expect(app_model.routes).to eq([route])
      expect(process.reload.routes).to eq([route])

      # verify audit event
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.map-route',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        app_model.name,
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid,
      })
    end
  end
end
