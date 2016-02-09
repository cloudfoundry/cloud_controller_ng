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

  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:process) { VCAP::CloudController::App.make(space: space, app_guid: app_model.guid, type: 'worker') }
  let(:route) { VCAP::CloudController::Route.make(space: space) }
  let(:developer) { make_developer_for_space(space) }
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
        'guid'       => guid,
        'created_at' => iso8601,
        'updated_at' => nil,

        'links'      => {
          'self'    => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings/#{guid}" },
          'app'     => { 'href' => "/v3/apps/#{app_model.guid}" },
          'route'   => { 'href' => "/v2/routes/#{route.guid}" },
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
        metadata:          { route_guid: route.guid }.to_json,
        organization_guid: space.organization.guid,
      })
    end
  end

  describe 'GET /v3/apps/:app_guid/route_mappings/:route_mapping_guid' do
    let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route, process_type: 'worker') }

    it 'retrieves the requests route mapping' do
      get "/v3/apps/#{app_model.guid}/route_mappings/#{route_mapping.guid}", {}, developer_headers

      expected_response = {
        'guid'       => route_mapping.guid,
        'created_at' => iso8601,
        'updated_at' => nil,

        'links'      => {
          'self'    => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings/#{route_mapping.guid}" },
          'app'     => { 'href' => "/v3/apps/#{app_model.guid}" },
          'route'   => { 'href' => "/v2/routes/#{route.guid}" },
          'process' => { 'href' => "/v3/apps/#{app_model.guid}/processes/#{process.type}" }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      # verify response
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/apps/:guid/route_mappings' do
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route) }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route, process_type: 'worker') }
    let!(:route_mapping3) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route, process_type: 'other') }

    it 'retrieves all the route mappings associated with the given app' do
      get "/v3/apps/#{app_model.guid}/route_mappings?per_page=2", {}, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings?page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings?page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings?page=2&per_page=2" },
          'previous'      => nil
        },
        'resources'  => [
          {
            'guid'       => route_mapping1.guid,
            'created_at' => iso8601,
            'updated_at' => nil,

            'links'      => {
              'self'    => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings/#{route_mapping1.guid}" },
              'app'     => { 'href' => "/v3/apps/#{app_model.guid}" },
              'route'   => { 'href' => "/v2/routes/#{route.guid}" },
              'process' => { 'href' => "/v3/apps/#{app_model.guid}/processes/web" }
            }
          },
          {
            'guid'       => route_mapping2.guid,
            'created_at' => iso8601,
            'updated_at' => nil,

            'links'      => {
              'self'    => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings/#{route_mapping2.guid}" },
              'app'     => { 'href' => "/v3/apps/#{app_model.guid}" },
              'route'   => { 'href' => "/v2/routes/#{route.guid}" },
              'process' => { 'href' => "/v3/apps/#{app_model.guid}/processes/worker" }
            }
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      # verify response
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
