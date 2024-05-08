require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Organizations', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:organization) { VCAP::CloudController::Organization.make }
  let(:quota_definition) { VCAP::CloudController::QuotaDefinition.make }
  let(:guid) { organization.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the Organization'
  end

  describe 'Standard endpoints' do
    shared_context 'updatable_fields' do |opts|
      field :name, 'The name of the organization', required: opts[:required], example_values: ['my-org-name']
      field :status, 'Status of the organization'
      field :quota_definition_guid, 'The guid of quota to associate with this organization', example_values: ['org-quota-def-guid']
      field :billing_enabled, 'If billing is enabled for this organization', deprecated: true
      field :default_isolation_segment_guid, 'The guid for the default isolation segment', experimental: true
    end

    standard_model_list :organization, VCAP::CloudController::OrganizationsController do
      request_parameter :'order-by', 'Parameter to order results by', valid_values: %w[name id]
    end
    standard_model_get :organization, nested_associations: [:quota_definition]
    standard_model_delete :organization do
      parameter :recursive, 'Will delete all spaces, apps, services, routes, and private domains associated with the org', valid_values: [true, false]
    end

    post '/v2/organizations/' do
      include_context 'updatable_fields', required: true
      example 'Creating an Organization' do
        client.post '/v2/organizations', Oj.dump(required_fields.merge(quota_definition_guid: quota_definition.guid)), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :organization
      end
    end

    put '/v2/organizations/:guid' do
      include_context 'updatable_fields', required: false
      include_context 'guid_parameter'

      let(:new_name) { 'New Organization Name' }

      example 'Update an Organization' do
        client.put "/v2/organizations/#{guid}", Oj.dump({ name: new_name, quota_definition_guid: quota_definition.guid }), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :organization, expected_values: { name: new_name }
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'
    let(:everything_user) { VCAP::CloudController::User.make }
    let(:user_user) { VCAP::CloudController::User.make }
    let(:username_map) do
      {
        everything_user.guid => 'everything@example.com',
        user_user.guid => 'user@example.com'
      }
    end

    describe 'User Roles' do
      before do
        organization.add_user(everything_user)
        organization.add_manager(everything_user)
        organization.add_auditor(everything_user)
        organization.add_billing_manager(everything_user)

        organization.add_user(user_user)

        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return(username_map)
      end

      get '/v2/organizations/:guid/user_roles' do
        pagination_parameters

        example 'Retrieving the roles of all Users in the Organization' do
          client.get "/v2/organizations/#{guid}/user_roles?results-per-page=1&page=1", {}, headers

          expect(status).to eq(200)
          expect(parsed_response['resources'].length).to eq(1)
          expect(parsed_response['resources'][0]['entity']['organization_roles']).
            to include('org_manager', 'org_auditor', 'billing_manager', 'org_user')
        end
      end
    end

    describe 'Spaces' do
      before do
        VCAP::CloudController::Space.make(organization:)
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :organization
    end

    describe 'Space Quota Definitions' do
      before do
        VCAP::CloudController::SpaceQuotaDefinition.make(organization:)
      end

      standard_model_list :space_quota_definition, VCAP::CloudController::SpaceQuotaDefinitionsController, outer_model: :organization
    end

    describe 'Domains' do
      standard_model_list :shared_domain, VCAP::CloudController::DomainsController, outer_model: :organization, path: :domains
    end

    describe 'Private Domains' do
      before do
        VCAP::CloudController::PrivateDomain.make(owning_organization: organization)
      end

      standard_model_list :private_domain, VCAP::CloudController::PrivateDomainsController, outer_model: :organization
    end

    describe 'Shared Private Domains' do
      before do
        organization.add_private_domain(associated_private_domain)
      end

      parameter :private_domain_guid, 'The guid of the private domain'

      let!(:associated_private_domain) { VCAP::CloudController::PrivateDomain.make }
      let(:associated_private_domain_guid) { associated_private_domain.guid }
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make }
      let(:private_domain_guid) { private_domain.guid }

      nested_model_associate :private_domain, :organization
      nested_model_remove :private_domain, :organization
    end

    describe 'Users' do
      before do
        organization.add_user(associated_user)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_user.guid => 'user@example.com' })
      end

      let!(:associated_user) { VCAP::CloudController::User.make }

      context 'by user guid' do
        let(:associated_user_guid) { associated_user.guid }
        let(:user) { VCAP::CloudController::User.make }
        let(:user_guid) { user.guid }

        standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization

        context 'has user guid param' do
          parameter :user_guid, 'The guid of the user'

          nested_model_associate :user, :organization
          nested_model_remove :user, :organization
        end
      end

      context 'by username' do
        body_parameter :username, "The user's name", required: true, example_values: ['user@example.com']

        put 'v2/organizations/:guid/users' do
          example 'Associate User with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: 'user-guid', origins_for_username: ['uaa'])

            client.put "v2/organizations/#{organization.guid}/users", Oj.dump({ username: 'user@example.com' }), headers
            expect(status).to eq(201)

            standard_entity_response parsed_response, :organization
          end
        end

        delete 'v2/organizations/:guid/users' do
          example 'Remove User with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: associated_user.guid, origins_for_username: ['uaa'])

            client.delete "v2/organizations/#{organization.guid}/users", Oj.dump({ username: 'user@example.com' }), headers
            expect(status).to eq(204)
          end
        end
      end
    end

    describe 'Managers' do
      before do
        organization.add_manager(associated_manager)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_manager.guid => 'manager@example.com' })
        make_manager_for_org(organization)
      end

      let!(:associated_manager) { VCAP::CloudController::User.make }
      let(:associated_manager_guid) { associated_manager.guid }

      context 'by user guid' do
        let(:manager) { VCAP::CloudController::User.make }
        let(:manager_guid) { manager.guid }

        standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :managers

        context 'has user guid param' do
          parameter :manager_guid, 'The guid of the user to associate as a manager'

          nested_model_associate :manager, :organization
          nested_model_remove :manager, :organization
        end
      end

      context 'by username' do
        body_parameter :username, "The user's name", required: true, example_values: ['user@example.com']

        put 'v2/organizations/:guid/managers' do
          example 'Associate Manager with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: 'user-guid', origins_for_username: ['uaa'])

            client.put "v2/organizations/#{organization.guid}/managers", Oj.dump({ username: 'user@example.com' }), headers
            expect(status).to eq(201)

            standard_entity_response parsed_response, :organization
          end
        end

        delete 'v2/organizations/:guid/managers' do
          example 'Remove Manager with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: associated_manager_guid, origins_for_username: ['uaa'])

            client.delete "v2/organizations/#{organization.guid}/managers", Oj.dump({ username: 'manage@example.com' }), headers
            expect(status).to eq(204)
          end
        end
      end
    end

    describe 'Billing Managers' do
      before do
        organization.add_billing_manager(associated_billing_manager)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_billing_manager.guid => 'billing_manager@example.com' })
      end

      let!(:associated_billing_manager) { VCAP::CloudController::User.make }
      let(:associated_billing_manager_guid) { associated_billing_manager.guid }

      context 'by user guid' do
        let(:billing_manager) { VCAP::CloudController::User.make }
        let(:billing_manager_guid) { billing_manager.guid }

        standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :billing_managers

        context 'has user guid param' do
          parameter :billing_manager_guid, 'The guid of the user'

          nested_model_associate :billing_manager, :organization
          nested_model_remove :billing_manager, :organization
        end
      end

      context 'by username' do
        body_parameter :username, "The user's name", required: true, example_values: ['user@example.com']

        put 'v2/organizations/:guid/billing_managers' do
          example 'Associate Billing Manager with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: 'user-guid', origins_for_username: ['uaa'])

            client.put "v2/organizations/#{organization.guid}/billing_managers", Oj.dump({ username: 'user@example.com' }), headers
            expect(status).to eq(201)

            standard_entity_response parsed_response, :organization
          end
        end

        delete 'v2/organizations/:guid/billing_managers' do
          example 'Remove Billing Manager with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: associated_billing_manager_guid, origins_for_username: ['uaa'])

            client.delete "v2/organizations/#{organization.guid}/billing_managers", Oj.dump({ username: 'billing_manager@example.com' }), headers
            expect(status).to eq(204)
          end
        end
      end
    end

    describe 'Auditors' do
      before do
        organization.add_auditor(associated_auditor)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_auditor.guid => 'auditor@example.com' })
      end

      let!(:associated_auditor) { VCAP::CloudController::User.make }
      let(:associated_auditor_guid) { associated_auditor.guid }

      context 'by user guid' do
        let(:auditor) { VCAP::CloudController::User.make }
        let(:auditor_guid) { auditor.guid }

        standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :auditors

        context 'has user guid param' do
          parameter :auditor_guid, 'The guid of the user'

          nested_model_associate :auditor, :organization
          nested_model_remove :auditor, :organization
        end
      end

      context 'by username' do
        body_parameter :username, "The user's name", required: true, example_values: ['user@example.com']

        put 'v2/organizations/:guid/auditors' do
          example 'Associate Auditor with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: 'user-guid', origins_for_username: ['uaa'])

            client.put "v2/organizations/#{organization.guid}/auditors", Oj.dump({ username: 'user@example.com' }), headers
            expect(status).to eq(201)

            standard_entity_response parsed_response, :organization
          end
        end

        delete 'v2/organizations/:guid/auditors' do
          example 'Remove Auditor with the Organization by Username' do
            uaa_client = double(:uaa_client)
            allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
            allow(uaa_client).to receive_messages(id_for_username: associated_auditor_guid, origins_for_username: ['uaa'])

            client.delete "v2/organizations/#{organization.guid}/auditors", Oj.dump({ username: 'auditor@example.com' }), headers
            expect(status).to eq(204)
          end
        end
      end
    end

    describe 'Services' do
      before do
        some_service = VCAP::CloudController::Service.make(active: true)
        VCAP::CloudController::ServicePlan.make(service: some_service, public: false)
        space = VCAP::CloudController::Space.make(organization:)
        VCAP::CloudController::ServicePlanVisibility.make(service_plan: some_service.service_plans.first, organization: space.organization)
      end

      standard_model_list :service, VCAP::CloudController::ServicesController, outer_model: :organization, path: :service, exclude_parameters: ['provider']
    end

    describe 'Memory Usage (Experimental)' do
      get '/v2/organizations/:guid/memory_usage' do
        example 'Retrieving organization memory usage' do
          client.get "/v2/organizations/#{guid}/memory_usage", {}, headers
          expect(status).to eq(200)

          expect(parsed_response['memory_usage_in_mb']).to eq(0)
        end
      end
    end

    describe 'Instance Usage (Experimental)' do
      get '/v2/organizations/:guid/instance_usage' do
        example 'Retrieving organization instance usage' do
          explanation "This endpoint returns a count of started app instances under an organization.
            Note that crashing apps are included in this count."

          space = VCAP::CloudController::Space.make(organization:)
          VCAP::CloudController::ProcessModelFactory.make(space: space, state: 'STARTED', instances: 3)

          client.get "/v2/organizations/#{guid}/instance_usage", {}, headers
          expect(status).to eq(200)

          expect(parsed_response['instance_usage']).to eq(3)
        end
      end
    end

    describe 'Isolation Segments (Experimental)' do
      delete '/v2/organizations/:guid/default_isolation_segment' do
        let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
        let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

        before do
          assigner.assign(isolation_segment, [organization])
          organization.default_isolation_segment_guid = isolation_segment.guid
          organization.save
        end

        example 'Deleting the organization\'s default isolation segment' do
          expect(organization.default_isolation_segment_guid).to eq(isolation_segment.guid)

          client.delete "/v2/organizations/#{guid}/default_isolation_segment", {}, headers

          expect(status).to eq 200
          expect(parsed_response['default_isolation_segment']).to be_nil
        end
      end
    end
  end
end
