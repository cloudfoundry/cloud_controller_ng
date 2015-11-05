require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Routes', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'tcp-group') }
  let(:route_path) { '/apps/v1/path' }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space) }
  let(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }
  let(:guid) { route.guid }

  let(:routing_api_client) { double('routing_api_client') }
  let(:router_group) {
    VCAP::CloudController::RoutingApi::RouterGroup.new({
                                                           'guid' => 'tcp-guid',
                                                           'type' => 'tcp',
                                                       })
  }
  before do
    allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                                                              and_return(routing_api_client)
    allow(routing_api_client).to receive(:router_group).and_return(router_group)
  end

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
      field :port, 'The port of the route. Supported for domains of TCP router groups only.', required: false,
                                                                                              valid_values: '1024-65535', example_values: [50000], experimental: true
      field :path, path_description, required: false, example_values: ['/apps/v1/path', '/apps/v2/path']
    end

    context 'with a route binding' do
      before do
        route_binding = VCAP::CloudController::RouteBinding.make(service_instance: service_instance, route: route)
        stub_unbind(route_binding)
      end

      standard_model_list :route, VCAP::CloudController::RoutesController
      standard_model_get :route, nested_associations: [:domain, :space, :service_instance]
      standard_model_delete :route, query_string: 'recursive=true'
    end

    post '/v2/routes/' do
      include_context 'updatable_fields', required: true

      param_description = <<EOF
Set to `true` to generate a random port. Defaults to `false`. Supported for domains for TCP router groups only. Takes precedence over manually specified port.
EOF
      parameter :generate_port, param_description, valid_values: [true, false], experimental: true

      example 'Creating a Route' do
        body = MultiJson.dump(
            required_fields.merge(
                domain_guid: domain.guid,
                space_guid: space.guid,
                port: 10000
            ), pretty: true
        )
        client.post '/v2/routes', body, headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :route
        expect(parsed_response['entity']['space_guid']).to eq(space.guid)
      end
    end

    put '/v2/routes/:guid' do
      include_context 'updatable_fields', required: false

      example 'Update a Route' do
        body = MultiJson.dump(
            {
                port: 10000
            }, pretty: true
        )
        client.put "/v2/routes/#{guid}", body, headers

        expect(status).to eq 201
        # expect(parsed_response['entity']['host']).to eq('')
        # expect(parsed_response['entity']['path']).to eq('/bar/baz')
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
