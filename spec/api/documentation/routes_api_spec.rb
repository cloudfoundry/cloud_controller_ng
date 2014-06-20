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
    field :guid, "The guid of the route.", required: false
    field :domain_guid, "The guid of the associated domain", required: true, example_values: [Sham.guid]
    field :space_guid, "The guid of the associated space", required: true, example_values: [Sham.guid]
    field :host, "The host portion of the route", required: false

    standard_model_list :route, VCAP::CloudController::RoutesController
    standard_model_get :route, nested_associations: [:domain, :space]
    standard_model_delete :route

    post "/v2/routes/" do
      example "Creating a route" do
        client.post "/v2/routes", Yajl::Encoder.encode(required_fields.merge(domain_guid: domain.guid, space_guid: space.guid)), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :route
      end
    end

    put "/v2/routes/:guid" do
      let(:new_host) { "new_host" }

      example "Update a route" do
        client.put "/v2/routes/#{guid}", Yajl::Encoder.encode(host: new_host), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :route, host: new_host
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the route.", required: true

    describe "Apps" do
      before do
        VCAP::CloudController::AppFactory.make(space: space, route_guids: [route.guid])
      end

      standard_model_list :app, VCAP::CloudController::AppsController, outer_model: :route
    end
  end
end
