require 'spec_helper'

RSpec.describe 'RouteMappings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/route_mappings/:guid' do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let(:route) { route_mapping.route }
    let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: process.app) }

    it 'displays the route mapping' do
      get "/v2/route_mappings/#{route_mapping.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => route_mapping.guid,
          'url'        => "/v2/route_mappings/#{route_mapping.guid}",
          'created_at' => iso8601,
          'updated_at' => iso8601
        },
        'entity' => {
          'app_port'   => nil,
          'app_guid'   => process.guid,
          'route_guid' => route.guid,
          'app_url'    => "/v2/apps/#{process.guid}",
          'route_url'  => "/v2/routes/#{route.guid}"
        }
      })
    end

    it 'does not display route mappings without a web process' do
      non_web_process       = VCAP::CloudController::ProcessModelFactory.make(space: space, type: 'non-web')
      non_displayed_mapping = VCAP::CloudController::RouteMappingModel.make(app: non_web_process.app, route: route, process_type: non_web_process.type)

      get "/v2/route_mappings/#{non_displayed_mapping.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(404)
    end

    describe 'app_port' do
      context 'diego app' do
        before do
          process.update(diego: true)
          route_mapping.update(app_port: 9090)
        end

        it 'displays the app_port' do
          get "/v2/route_mappings/#{route_mapping.guid}", nil, headers_for(user)
          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['entity']['app_port']).to eq(9090)
        end
      end

      context 'dea app' do
        before do
          process.update(diego: false)
        end

        it 'displays nil for app_port' do
          get "/v2/route_mappings/#{route_mapping.guid}", nil, headers_for(user)
          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['entity']['app_port']).to be_nil
        end
      end
    end
  end

  describe 'GET /v2/route_mappings' do
    let(:process1) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let(:route1) { route_mapping1.route }
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: process1.app) }

    let(:process2) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let(:route2) { route_mapping2.route }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: process2.app) }

    let!(:route_mapping3) { VCAP::CloudController::RouteMappingModel.make }

    it 'lists all route mappings' do
      get '/v2/route_mappings', nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 2,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => route_mapping1.guid,
                'url'        => "/v2/route_mappings/#{route_mapping1.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'app_port'   => nil,
                'app_guid'   => process1.guid,
                'route_guid' => route1.guid,
                'app_url'    => "/v2/apps/#{process1.guid}",
                'route_url'  => "/v2/routes/#{route1.guid}"
              }
            },
            {
              'metadata' => {
                'guid'       => route_mapping2.guid,
                'url'        => "/v2/route_mappings/#{route_mapping2.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'app_port'   => nil,
                'app_guid'   => process2.guid,
                'route_guid' => route2.guid,
                'app_url'    => "/v2/apps/#{process2.guid}",
                'route_url'  => "/v2/routes/#{route2.guid}"
              }
            }
          ]
        }
      )
    end

    it 'does not list mappings to non-web processes' do
      non_web_process       = VCAP::CloudController::ProcessModelFactory.make(space: space, type: 'non-web')
      non_web_route_mapping = VCAP::CloudController::RouteMappingModel.make(app: non_web_process.app, process_type: non_web_process.type)

      get '/v2/route_mappings', nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['resources'].map { |r| r['metadata']['guid'] }).not_to include(non_web_route_mapping.guid)
    end
  end

  describe 'POST /v2/route_mappings' do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space, diego: true, ports: [9090]) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }

    it 'creates a route mapping' do
      request = MultiJson.dump(
        {
          route_guid: route.guid,
          app_guid:   process.guid,
          app_port:   9090
        })

      post '/v2/route_mappings', request, headers_for(user)
      expect(last_response.status).to eq(201)

      parsed_response = MultiJson.load(last_response.body)
      route_mapping   = VCAP::CloudController::RouteMappingModel.last

      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => route_mapping.guid,
          'url'        => "/v2/route_mappings/#{route_mapping.guid}",
          'created_at' => iso8601,
          'updated_at' => iso8601
        },
        'entity' => {
          'app_port'   => 9090,
          'app_guid'   => process.guid,
          'route_guid' => route.guid,
          'app_url'    => "/v2/apps/#{process.guid}",
          'route_url'  => "/v2/routes/#{route.guid}"
        }
      })

      expect(route_mapping.app_guid).to eq(process.guid)
      expect(route_mapping.route_guid).to eq(route.guid)
      expect(route_mapping.app_port).to eq(9090)
      expect(route_mapping.process_type).to eq('web')

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.app.map-route')
      expect(event.actee_type).to eq('app')
      expect(event.actee).to eq(process.guid)
      expect(event.metadata).to eq({ 'route_guid' => route.guid, 'app_port' => 9090, 'route_mapping_guid' => route_mapping.guid, 'process_type' => 'web' })
    end
  end

  describe 'DELETE /V2/route_mappings' do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space, diego: true, ports: [9090]) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route) }

    it 'deletes a route mapping' do
      delete "/v2/route_mappings/#{route_mapping.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(204)

      expect(route_mapping.exists?).to be_falsey

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.app.unmap-route')
      expect(event.actee_type).to eq('app')
      expect(event.actee).to eq(process.guid)
      expect(event.metadata).to eq({ 'route_guid' => route.guid, 'route_mapping_guid' => route_mapping.guid, 'process_type' => 'web' })
    end
  end
end
