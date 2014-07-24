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
      example "Creating an Organization" do
        client.post "/v2/organizations", MultiJson.dump(required_fields), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :organization
      end
    end

    put "/v2/organizations/:guid" do
      let(:new_name) { "New Organization Name" }

      example "Update an Organization" do
        client.put "/v2/organizations/#{guid}", MultiJson.dump(name: new_name), headers
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

    describe "Space Quota Definitions" do
      before do
        VCAP::CloudController::SpaceQuotaDefinition.make(organization: organization)
      end

      standard_model_list :space_quota_definition, VCAP::CloudController::SpaceQuotaDefinitionsController, outer_model: :organization
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
        organization.add_user(associated_user)
      end

      let!(:associated_user) { VCAP::CloudController::User.make }
      let(:associated_user_guid) { associated_user.guid }
      let(:user) { VCAP::CloudController::User.make }
      let(:user_guid) { user.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization
      nested_model_associate :user, :organization
      nested_model_remove :user, :organization
    end

    describe "Managers" do
      before do
        organization.add_manager(associated_manager)
        make_manager_for_org(organization)
      end

      let!(:associated_manager) { VCAP::CloudController::User.make }
      let(:associated_manager_guid) { associated_manager.guid }
      let(:manager) { VCAP::CloudController::User.make }
      let(:manager_guid) { manager.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :managers
      nested_model_associate :manager, :organization
      nested_model_remove :manager, :organization
    end

    describe "Billing Managers" do
      before do
        organization.add_billing_manager(associated_billing_manager)
      end

      let!(:associated_billing_manager) { VCAP::CloudController::User.make }
      let(:associated_billing_manager_guid) { associated_billing_manager.guid }
      let(:billing_manager) { VCAP::CloudController::User.make }
      let(:billing_manager_guid) { billing_manager.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :billing_managers
      nested_model_associate :billing_manager, :organization
      nested_model_remove :billing_manager, :organization
    end

    describe "Auditors" do
      before do
        organization.add_auditor(associated_auditor)
      end

      let!(:associated_auditor) { VCAP::CloudController::User.make }
      let(:associated_auditor_guid) { associated_auditor.guid }
      let(:auditor) { VCAP::CloudController::User.make }
      let(:auditor_guid) { auditor.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :auditors
      nested_model_associate :auditor, :organization
      nested_model_remove :auditor, :organization
    end
  end
end
