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

    describe "Spaces" do
      before do
        VCAP::CloudController::Space.make(organization: organization)
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :organization
    end

    describe "Domains" do
      standard_model_list :shared_domain, VCAP::CloudController::DomainsController, outer_model: :organization, path: :domains
    end

    describe "Private Domains" do
      before do
        VCAP::CloudController::PrivateDomain.make(owning_organization: organization)
      end

      standard_model_list :private_domain, VCAP::CloudController::PrivateDomainsController, outer_model: :organization
    end

    describe "Users" do
      before do
        make_user_for_org(organization)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization
    end

    describe "Managers" do
      before do
        make_manager_for_org(organization)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :managers
    end

    describe "Billing Managers" do
      before do
        make_billing_manager_for_org(organization)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :billing_managers
    end

    describe "Auditors" do
      before do
        make_auditor_for_org(organization)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :auditors
    end
  end
end
