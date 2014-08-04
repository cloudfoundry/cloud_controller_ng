require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Routes", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:organization) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: organization) }
  let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: organization) }
  let!(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }
  let(:guid) { route.guid }

  authenticated_request

  describe "Standard endpoints" do
    shared_context "updatable_fields" do |opts|
      field :guid, "The guid of the route."
      field :domain_guid, "The guid of the associated domain", required: opts[:required], example_values: [Sham.guid]
      field :space_guid, "The guid of the associated space", required: opts[:required], example_values: [Sham.guid]
      field :host, "The host portion of the route"
    end

    standard_model_list :route, VCAP::CloudController::RoutesController
    standard_model_get :route, nested_associations: [:domain, :space]
    standard_model_delete :route

    post "/v2/routes/" do
      include_context "updatable_fields", required: true

      example "Creating a Route" do
        client.post "/v2/routes", MultiJson.dump(required_fields.merge(domain_guid: domain.guid, space_guid: space.guid), pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :route
      end
    end

    put "/v2/routes/:guid" do
      include_context "updatable_fields", required: false

      let(:new_host) { "new_host" }

      example "Update a Route" do
        client.put "/v2/routes/#{guid}", MultiJson.dump({ host: new_host }, pretty: true), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :route, host: new_host
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the route.", required: true

    describe "Apps" do
      let!(:associated_app) { VCAP::CloudController::AppFactory.make(space: space, route_guids: [route.guid]) }
      let(:associated_app_guid) { associated_app.guid }
      let(:app_obj) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:app_guid) { app_obj.guid }

      standard_model_list :app, VCAP::CloudController::AppsController, outer_model: :route
      nested_model_associate :app, :route
      nested_model_remove :app, :route
    end
  end
end
