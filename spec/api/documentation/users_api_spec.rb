require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Users", type: :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:user) { VCAP::CloudController::User.make(default_space: space) }
  let(:guid) { user.guid }
  let(:space) { VCAP::CloudController::Space.make }

  authenticated_request

  describe "Standard endpoints" do
    field :guid, "The guid of the user.", required: false
    field :default_space_guid, "The guid of the default space for apps created by this user.", required: false
    field :admin, "Whether the user is an admin (Use UAA instead).", required: false, deprecated: true
    field :default_space_url, "The url of the default space for apps created by the user.", required: false, readonly: true
    field :spaces_url, "The url of the spaces this user is a developer of.", required: false, readonly: true
    field :organizations_url, "The url of the organizations this user in a member of.", required: false, readonly: true
    field :managed_organizations_url, "The url of the organizations this user in a manager of.", required: false, readonly: true
    field :billing_managed_organizations_url, "The url of the organizations this user in a billing manager of.", required: false, readonly: true
    field :audited_organizations_url, "The url of the organizations this user in a auditor of.", required: false, readonly: true
    field :managed_spaces_url, "The url of the spaces this user in a manager of.", required: false, readonly: true
    field :audited_spaces_url, "The url of the spaces this user in a auditor of.", required: false, readonly: true

    standard_model_list(:user, VCAP::CloudController::UsersController)
    standard_model_get(:user, nested_associations: [:default_space])
    standard_model_delete(:user)

    put "/v2/users/:guid" do
      request_parameter :guid, "The guid for the user to alter"

      example "Update a User's default Space" do
        new_space = VCAP::CloudController::Space.make
        client.put "/v2/users/#{guid}", Yajl::Encoder.encode(default_space_guid: new_space.guid), headers

        expect(status).to eq 201
        standard_entity_response parsed_response, :user, :default_space_guid => new_space.guid
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the user.", required: true

    describe "Developer Spaces" do
      before do
        associated_space.organization.add_user(user)
        associated_space.add_developer(user)

        space.organization.add_user(user)
      end

      let!(:associated_space) { VCAP::CloudController::Space.make }
      let(:associated_space_guid) { associated_space.guid }
      let(:space) { VCAP::CloudController::Space.make }
      let(:space_guid) { space.guid }

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user
      nested_model_associate :space, :user
      nested_model_remove :space, :user
    end

    describe "Managed Spaces" do
      before do
        associated_managed_space.organization.add_user(user)
        associated_managed_space.add_manager(user)

        managed_space.organization.add_user(user)
      end

      let!(:associated_managed_space) { VCAP::CloudController::Space.make }
      let(:associated_managed_space_guid) { associated_managed_space.guid }
      let(:managed_space) { VCAP::CloudController::Space.make }
      let(:managed_space_guid) { managed_space.guid }


      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user, path: :managed_spaces
      nested_model_associate :managed_space, :user
      nested_model_remove :managed_space, :user
    end

    describe "Audited Spaces" do
      before do
        associated_audited_space.organization.add_user(user)
        associated_audited_space.add_auditor(user)

        audited_space.organization.add_user(user)
      end

      let!(:associated_audited_space) { VCAP::CloudController::Space.make }
      let(:associated_audited_space_guid) { associated_audited_space.guid }
      let(:audited_space) { VCAP::CloudController::Space.make }
      let(:audited_space_guid) { audited_space.guid }

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user, path: :audited_spaces
      nested_model_associate :audited_space, :user
      nested_model_remove :audited_space, :user
    end

    describe "Organizations" do
      before do
        associated_organization.add_user(user)
      end

      let!(:associated_organization) { VCAP::CloudController::Organization.make }
      let(:associated_organization_guid) { associated_organization.guid }
      let(:organization) { VCAP::CloudController::Organization.make }
      let(:organization_guid) { organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user
      nested_model_associate :organization, :user
      nested_model_remove :organization, :user
    end

    describe "Managed Organizations" do
      before do
        managed_organization.add_user(user)

        make_manager_for_org(associated_managed_organization)
        associated_managed_organization.add_manager(user)
      end

      let!(:associated_managed_organization) { VCAP::CloudController::Organization.make }
      let(:associated_managed_organization_guid) { associated_managed_organization.guid }
      let(:managed_organization) { VCAP::CloudController::Organization.make }
      let(:managed_organization_guid) { managed_organization.guid }
      
      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :managed_organizations
      nested_model_associate :managed_organization, :user
      nested_model_remove :managed_organization, :user
    end

    describe "Billing Managed Organizations" do
      before do
        billing_managed_organization.add_user(user)

        associated_billing_managed_organization.add_billing_manager(user)
      end

      let!(:associated_billing_managed_organization) { VCAP::CloudController::Organization.make }
      let(:associated_billing_managed_organization_guid) { associated_billing_managed_organization.guid }
      let(:billing_managed_organization) { VCAP::CloudController::Organization.make }
      let(:billing_managed_organization_guid) { billing_managed_organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :billing_managed_organizations
      nested_model_associate :billing_managed_organization, :user
      nested_model_remove :billing_managed_organization, :user
    end

    describe "Audited Organizations" do
      before do
        audited_organization.add_user(user)

        associated_audited_organization.add_auditor(user)
      end

      let!(:associated_audited_organization) { VCAP::CloudController::Organization.make }
      let(:associated_audited_organization_guid) { associated_audited_organization.guid }
      let(:audited_organization) { VCAP::CloudController::Organization.make }
      let(:audited_organization_guid) { audited_organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :audited_organizations
      nested_model_associate :audited_organization, :user
      nested_model_remove :audited_organization, :user
    end
  end
end
