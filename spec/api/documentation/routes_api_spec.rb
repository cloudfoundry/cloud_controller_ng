require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Routes', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make }
  let(:space) { VCAP::CloudController::Space.make(organization: space_quota.organization, space_quota_definition: space_quota) }
  let(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'tcp-group') }
  let(:route_path) { '/apps/v1/path' }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space) }
  let(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }
  let(:guid) { route.guid }

  let(:routing_api_client) { double('routing_api_client', enabled?: true) }
  let(:router_group) {
    VCAP::CloudController::RoutingApi::RouterGroup.new({
                                                           'guid' => 'tcp-guid',
                                                           'type' => 'tcp',
                                                           'reservable_ports' => '1024-65535'
                                                       })
  }
  before do
    allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
      and_return(routing_api_client)
    allow(routing_api_client).to receive(:router_group).and_return(router_group)
    allow_any_instance_of(VCAP::CloudController::RouteValidator).to receive(:validate)
  end

  authenticated_request

  shared_context 'guid_field' do
    field :guid, 'The guid of the route.'
  end

  path_description = 'The path for a route as raw text.'
  path_description += ' 1) Paths must be between 2 and 128 characters'
  path_description += ' 2) Paths must start with a forward slash "/"'
  path_description += ' 3) Paths must not contain a "?"'

  describe 'Standard endpoints' do
    shared_context 'updatable_fields' do |opts|
      field :domain_guid, 'The guid of the associated domain', required: opts[:required], example_values: [Sham.guid]
      field :space_guid, 'The guid of the associated space', required: opts[:required], example_values: [Sham.guid]
      field :host, 'The host portion of the route. Required for shared-domains.'
      field :port, 'The port of the route. Supported for domains of TCP router groups only.', required: false,
                                                                                              valid_values: '1024-65535', example_values: [50000]
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

      def after_standard_model_delete(guid)
        event = VCAP::CloudController::Event.find(type: 'audit.route.delete-request', actee: guid)
        audited_event event
      end
    end

    post '/v2/routes/' do
      include_context 'updatable_fields', required: true

      param_description = <<~EOF
        Set to `true` to generate a random port. Defaults to `false`. Supported for domains for TCP router groups only. Takes precedence over manually specified port.
EOF
      parameter :generate_port, param_description, valid_values: [true, false]

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
        route_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.route.create', actee: route_guid)
      end
    end

    put '/v2/routes/:guid' do
      include_context 'guid_field', required: true
      include_context 'updatable_fields', required: false

      example 'Update a Route' do
        body = MultiJson.dump(
          {
              port: 10000
          }, pretty: true
        )
        client.put "/v2/routes/#{guid}", body, headers

        expect(status).to eq 201

        standard_entity_response parsed_response, :route
        route_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.route.update', actee: route_guid)
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_field', required: true

    describe 'Apps' do
      let!(:associated_process) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:associated_app_guid) { associated_process.guid }
      let(:process) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:app_guid) { process.guid }

      before do
        VCAP::CloudController::RouteMappingModel.make(app: process.app, process_type: process.type, route: route)
      end

      parameter :app_guid, 'The guid of the app'

      standard_model_list 'ProcessModel', VCAP::CloudController::AppsController, path: 'app', outer_model: :route
      nested_model_associate :app, :route
      nested_model_remove :app, :route
    end
  end

  describe 'Reserved Routes' do
    let(:route) { VCAP::CloudController::Route.make(domain: domain, port: 61000, host: '', space: space) }
    get '/v2/routes/reserved/domain/:domain_guid?host=:host&path=:path&port=:port' do
      request_parameter :host, 'The host portion of the route. Required for shared-domains.', required: false
      request_parameter :path, path_description, required: false, example_values: ['/apps/v1/path', '/apps/v2/path']
      request_parameter :port, 'The port of the route. Supported for domains of TCP router groups only.',
        required: false, example_values: [60027, 1234]

      example 'Check a Route exists' do
        explanation 'This endpoint returns a status code of 204 if the route exists, and 404 if it does not.'

        client.get "/v2/routes/reserved/domain/#{domain.guid}?port=#{route.port}", {}, headers
        expect(status).to eq 204
      end
    end
  end

  describe 'HTTP Reserved Routes' do
    before do
      route.path = route_path
      route.save
    end
    get '/v2/routes/reserved/domain/:domain_guid/host/:host?path=:path' do
      request_parameter :host, 'The host portion of the route. Required for shared-domains.'
      request_parameter :path, path_description, required: false, example_values: ['/apps/v1/path', '/apps/v2/path']

      example 'Check a HTTP Route exists' do
        explanation 'This endpoint returns a status code of 204 if the route exists, and 404 if it does not.'

        client.get "/v2/routes/reserved/domain/#{domain.guid}/host/#{route.host}?path=#{route_path}", {}, headers
        expect(status).to eq 204
      end
    end
  end
end
