require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Routes', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:organization) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: organization) }
  let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: organization) }
  let(:route_path) { '/apps/v1/path' }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space) }
  let!(:route) { VCAP::CloudController::Route.make(domain: domain, space: space, service_instance: service_instance) }
  let(:guid) { route.guid }

  authenticated_request

  describe 'Standard endpoints' do
    path_description = 'The path for a route as raw text.'
    path_description += ' 1) Paths must be between 2 and 128 characters'
    path_description += ' 2) Paths must start with a /'
    path_description += ' 3) Paths must not contain a "?"'

    shared_context 'updatable_fields' do |opts|
      field :guid, 'The guid of the route.'
      field :domain_guid, 'The guid of the associated domain', required: opts[:required], example_values: [Sham.guid]
      field :space_guid, 'The guid of the associated space', required: opts[:required], example_values: [Sham.guid]
      field :host, 'The host portion of the route'
      field :path, path_description, required: false, example_values: ['/apps/v1/path', '/apps/v2/path']
    end

    standard_model_list :route, VCAP::CloudController::RoutesController
    standard_model_get :route, nested_associations: [:domain, :space]
    standard_model_delete :route

    post '/v2/routes/' do
      include_context 'updatable_fields', required: true

      example 'Creating a Route' do
        body = MultiJson.dump(
          required_fields.merge(
            domain_guid: domain.guid,
            space_guid: space.guid,
            path: route_path,
          ), pretty: true
        )
        client.post '/v2/routes', body, headers

        expect(status).to eq(201)

        standard_entity_response parsed_response, :route
        expect(parsed_response['entity']['path']).to eq(route_path)
        expect(parsed_response['entity']['space_guid']).to eq(space.guid)
      end
    end

    put '/v2/routes/:guid' do
      include_context 'updatable_fields', required: false

      let(:new_host) { 'new_host' }

      example 'Update a Route' do
        body = MultiJson.dump(
          {
            host: new_host,
            path: route_path,
          }, pretty: true
        )
        client.put "/v2/routes/#{guid}", body, headers

        expect(status).to eq 201
        standard_entity_response parsed_response, :route, host: new_host
        expect(parsed_response['entity']['path']).to eq(route_path)
      end
    end
  end

  describe 'Nested endpoints' do
    field :guid, 'The guid of the route.', required: true

    describe 'Apps' do
      let!(:associated_app) { VCAP::CloudController::AppFactory.make(space: space, route_guids: [route.guid]) }
      let(:associated_app_guid) { associated_app.guid }
      let(:app_obj) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:app_guid) { app_obj.guid }

      parameter :app_guid, 'The guid of the app'

      standard_model_list :app, VCAP::CloudController::AppsController, outer_model: :route
      nested_model_associate :app, :route
      nested_model_remove :app, :route
    end
  end

  describe 'Reserved Routes' do
    before do
      route.path = route_path
      route.save
    end
    get '/v2/routes/reserved/domain/:domain_guid/host/:host?path=:path' do
      request_parameter :domain_guid, 'The guid of a domain'
      request_parameter :host, 'The host portion of the route'
      request_parameter :path, 'The path of a route', required: false, example_values: ['/apps/v1/path', '/apps/v2/path']

      example 'Check a Route exists' do
        client.get "/v2/routes/reserved/domain/#{domain.guid}/host/#{route.host}?path=#{route_path}", {}, headers
        expect(status).to eq 204
      end
    end
  end
end
