require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Users', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:user) { VCAP::CloudController::User.make(default_space: space) }
  let(:guid) { user.guid }
  let(:space) { VCAP::CloudController::Space.make }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the User'
  end

  shared_context 'updatable_fields' do
    field :default_space_guid, 'The guid of the default space for apps created by this user.'
    field :admin, 'Whether the user is an admin (Use UAA instead).', deprecated: true
  end

  describe 'Standard endpoints' do
    before do
      allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ guid => 'user@example.com' })
    end

    standard_model_list(:user, VCAP::CloudController::UsersController)
    standard_model_get(:user, nested_associations: [:default_space])
    standard_model_delete(:user)

    post '/v2/users/' do
      field :guid, 'The UAA guid of the user to create.', required: true, example_values: [Sham.guid]
      include_context 'updatable_fields'

      example 'Creating a User' do
        client.post '/v2/users', fields_json, headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :user
      end
    end

    put '/v2/users/:guid' do
      include_context 'guid_parameter'
      include_context 'updatable_fields'

      example 'Updating a User' do
        new_space = VCAP::CloudController::Space.make
        client.put "/v2/users/#{guid}", MultiJson.dump({ default_space_guid: new_space.guid }, pretty: true), headers

        expect(status).to eq 201
        standard_entity_response parsed_response, :user, default_space_guid: new_space.guid
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'

    describe 'Developer Spaces' do
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

      context 'has space guid param' do
        parameter :space_guid, 'The guid of the space'

        nested_model_associate :space, :user
        nested_model_remove :space, :user
      end
    end

    describe 'Managed Spaces' do
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

      context 'has space guid param' do
        parameter :managed_space_guid, 'The guid of the managed space'

        nested_model_associate :managed_space, :user
        nested_model_remove :managed_space, :user
      end
    end

    describe 'Audited Spaces' do
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

      context 'has space guid param' do
        parameter :audited_space_guid, 'The guid of the audited space'

        nested_model_associate :audited_space, :user
        nested_model_remove :audited_space, :user
      end
    end

    describe 'Organizations' do
      before do
        associated_organization.add_user(user)
      end

      let!(:associated_organization) { VCAP::CloudController::Organization.make }
      let(:associated_organization_guid) { associated_organization.guid }
      let(:organization) { VCAP::CloudController::Organization.make }
      let(:organization_guid) { organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user

      context 'has organization guid param' do
        parameter :organization_guid, 'The guid of the organization'

        nested_model_associate :organization, :user
        nested_model_remove :organization, :user
      end
    end

    describe 'Managed Organizations' do
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

      context 'has organization guid param' do
        parameter :managed_organization_guid, 'The guid of the managed_organization'

        nested_model_associate :managed_organization, :user
        nested_model_remove :managed_organization, :user
      end
    end

    describe 'Billing Managed Organizations' do
      before do
        billing_managed_organization.add_user(user)

        associated_billing_managed_organization.add_billing_manager(user)
      end

      let!(:associated_billing_managed_organization) { VCAP::CloudController::Organization.make }
      let(:associated_billing_managed_organization_guid) { associated_billing_managed_organization.guid }
      let(:billing_managed_organization) { VCAP::CloudController::Organization.make }
      let(:billing_managed_organization_guid) { billing_managed_organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :billing_managed_organizations

      context 'has organization guid param' do
        parameter :billing_managed_organization_guid, 'The guid of the billing managed organization'

        nested_model_associate :billing_managed_organization, :user
        nested_model_remove :billing_managed_organization, :user
      end
    end

    describe 'Audited Organizations' do
      before do
        audited_organization.add_user(user)

        associated_audited_organization.add_auditor(user)
      end

      let!(:associated_audited_organization) { VCAP::CloudController::Organization.make }
      let(:associated_audited_organization_guid) { associated_audited_organization.guid }
      let(:audited_organization) { VCAP::CloudController::Organization.make }
      let(:audited_organization_guid) { audited_organization.guid }

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :user, path: :audited_organizations

      context 'has organization guid param' do
        parameter :audited_organization_guid, 'The guid of the audited organization'

        nested_model_associate :audited_organization, :user
        nested_model_remove :audited_organization, :user
      end
    end
  end
end
