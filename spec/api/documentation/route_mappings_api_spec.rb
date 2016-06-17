require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Routes Mapping', type: [:api, :legacy_api] do
  let!(:app_obj) { VCAP::CloudController::AppFactory.make(diego: true, ports: [8888, 8889]) }
  let!(:route) { VCAP::CloudController::Route.make(space: app_obj.space) }

  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }

  authenticated_request

  describe 'Standard endpoints' do
    shared_context 'guid_fields' do |opts|
      field :app_guid, 'The guid of the bound application.', required: true, example_values: [Sham.guid]
      field :route_guid, 'The guid of the bound route.', required: true, example_values: [Sham.guid]
    end

    context 'when a route mapping exists' do
      let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(route: route, app: app_obj) }
      let(:guid) { route_mapping.guid }

      standard_model_get :route_mapping
      standard_model_list :route_mapping, VCAP::CloudController::RouteMappingsController
      standard_model_delete :route_mapping
    end

    post '/v2/route_mappings' do
      include_context 'guid_fields'
      field :app_port, 'Port on which the application should
                      listen, and to which requests for the
                      mapped route will be routed. Must be
                      among those already configured for the app.
                      If a port is not specified when mapping the
                      route, the first one in the list of those
                      configured for the app will be chosen.', required: false

      example 'Mapping an App and a Route' do
        body = MultiJson.dump(
          { app_guid: app_obj.guid, route_guid: route.guid, app_port: 8888 }, pretty: true
        )

        client.post '/v2/route_mappings', body, headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :route_mapping
        expect(parsed_response['entity']['app_guid']).to eq(app_obj.guid)
        expect(parsed_response['entity']['route_guid']).to eq(route.guid)
        expect(parsed_response['entity']['app_port']).to eq(8888)
      end
    end

    context 'when updating a route mapping' do
      let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(route: route, app: app_obj) }
      let!(:guid) { route_mapping.guid }

      put '/v2/route_mappings/:guid' do
        field :app_port, 'Port on which the application should listen,
                          and to which requests for the mapped route will be routed.
                          Must be among those already configured for the app.', required: true

        example 'Updating a Route Mapping' do
          body = MultiJson.dump(
            { app_port: 8889 }, pretty: true
          )

          client.put "/v2/route_mappings/#{guid}", body, headers
          expect(status).to eq(201)

          standard_entity_response parsed_response, :route_mapping
          expect(parsed_response['entity']['app_guid']).to eq(app_obj.guid)
          expect(parsed_response['entity']['route_guid']).to eq(route.guid)
          expect(parsed_response['entity']['app_port']).to eq(8889)
        end
      end
    end
  end
end
