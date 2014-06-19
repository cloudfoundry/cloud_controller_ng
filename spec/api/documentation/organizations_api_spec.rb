require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Organizations", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:organization) { VCAP::CloudController::Organization.make }
  let(:guid) { organization.guid }

  authenticated_request

  describe "Standard endpoints" do
    field :guid, "The guid of the organization.", required: false
    field :name, "The name of the organization", required: true, example_values: ["my-org-name"]
    field :status, "Status of the organization"
    field :billing_enabled, "If billing is enabled for this organization", deprecated: true

    standard_model_list :organization, VCAP::CloudController::OrganizationsController
    standard_model_get :organization, nested_associations: [:quota_definition]
    standard_model_delete :organization

    post "/v2/organizations/" do
      example "Creating an organization" do
        client.post "/v2/organizations", Yajl::Encoder.encode(required_fields), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :organization
      end
    end

    put "/v2/organizations/:guid" do
      let(:new_name) { "New Organization Name" }

      example "Update an organization" do
        client.put "/v2/organizations/#{guid}", Yajl::Encoder.encode(name: new_name), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :organization, name: new_name
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the organization.", required: true

    get "/v2/organizations/:guid/spaces" do
      before do
        VCAP::CloudController::Space.make(organization: organization)
      end

      example "List all spaces for an organization" do
        client.get "/v2/organizations/#{guid}/spaces", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :space
      end
    end

    get "/v2/organizations/:guid/domains" do
      example "List all domains for an organization" do
        client.get "/v2/organizations/#{guid}/domains", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :shared_domain
      end
    end

    get "/v2/organizations/:guid/private_domains" do
      before do
        VCAP::CloudController::PrivateDomain.make(owning_organization: organization)
      end

      example "List all private domains for an organization" do
        client.get "/v2/organizations/#{guid}/private_domains", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :private_domain
      end
    end

    get "/v2/organizations/:guid/users" do
      before do
        make_user_for_org(organization)
      end

      example "List all users for an organization" do
        client.get "/v2/organizations/#{guid}/users", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :user
      end
    end

    get "/v2/organizations/:guid/managers" do
      before do
        make_manager_for_org(organization)
      end

      example "List all managers for an organization" do
        client.get "/v2/organizations/#{guid}/managers", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :user
      end
    end

    get "/v2/organizations/:guid/billing_managers" do
      before do
        make_billing_manager_for_org(organization)
      end

      example "List all billing managers for an organization" do
        client.get "/v2/organizations/#{guid}/billing_managers", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :user
      end
    end

    get "/v2/organizations/:guid/auditors" do
      before do
        make_auditor_for_org(organization)
      end

      example "List all auditors for an organization" do
        client.get "/v2/organizations/#{guid}/auditors", {}, headers
        expect(status).to eq 200
        standard_list_response parsed_response, :user
      end
    end
  end
end
