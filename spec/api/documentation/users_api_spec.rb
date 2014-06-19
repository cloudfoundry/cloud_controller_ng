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

      example "Update a User's default space" do
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
        space = VCAP::CloudController::Space.make
        user.add_organization space.organization
        space.add_developer user
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user
    end

    describe "Managed Spaces" do
      before do
        space = VCAP::CloudController::Space.make
        user.add_organization space.organization
        space.add_manager user
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user, path: :managed_spaces
    end

    describe "Audited Spaces" do
      before do
        space = VCAP::CloudController::Space.make
        user.add_organization space.organization
        space.add_auditor user
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :user, path: :audited_spaces
    end

    describe "Organizations" do
      before do
        organization = VCAP::CloudController::Organization.make
        user.add_organization organization
      end

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user
    end

    describe "Managed Organizations" do
      before do
        organization = VCAP::CloudController::Organization.make
        user.add_organization organization
        organization.add_manager(user)
      end

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :managed_organizations
    end

    describe "Billing Managed Organizations" do
      before do
        organization = VCAP::CloudController::Organization.make
        user.add_organization organization
        organization.add_billing_manager(user)
      end

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :billing_managed_organizations
    end

    describe "Audited Organizations" do
      before do
        organization = VCAP::CloudController::Organization.make
        user.add_organization organization
        organization.add_auditor(user)
      end

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :audited_organizations
    end
  end
end
