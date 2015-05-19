require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Organizations', type: [:api, :legacy_api] do
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
    end

    standard_model_list :organization, VCAP::CloudController::OrganizationsController
    standard_model_get :organization, nested_associations: [:quota_definition]
    standard_model_delete :organization

    post '/v2/organizations/' do
      include_context 'updatable_fields', required: true
      example 'Creating an Organization' do
        client.post '/v2/organizations', MultiJson.dump(required_fields.merge(quota_definition_guid: quota_definition.guid), pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :organization
      end
    end

    put '/v2/organizations/:guid' do
      include_context 'updatable_fields', required: false
      include_context 'guid_parameter'

      let(:new_name) { 'New Organization Name' }

      example 'Update an Organization' do
        client.put "/v2/organizations/#{guid}", MultiJson.dump({ name: new_name, quota_definition_guid: quota_definition.guid }, pretty: true), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :organization, name: new_name
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
        user_user.guid => 'user@example.com',
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

    describe 'Quota Usage' do
      before do
        organization.add_space(space)
        app_obj.add_route(route)
        space.add_service_instance(service_instance)
        space.add_app(app_obj)
      end

      let(:space) { VCAP::CloudController::Space.make(organization: organization) }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:app_obj) { VCAP::CloudController::AppFactory.make(space: space, instances: 1, memory: 500, state: 'STARTED') }

      get '/v2/organizations/:guid/quota_usage' do
        example 'Retrieving quota usage for the Organization' do
          client.get "/v2/organizations/#{guid}/quota_usage", {}, headers

          expect(status).to eq(200)
          expect(parsed_response['entity']['org_usage']).
            to include('routes', 'services', 'memory')
        end
      end
    end

    describe 'Spaces' do
      before do
        VCAP::CloudController::Space.make(organization: organization)
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :organization
    end

    describe 'Space Quota Definitions' do
      before do
        VCAP::CloudController::SpaceQuotaDefinition.make(organization: organization)
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

      let!(:associated_private_domain) { VCAP::CloudController::PrivateDomain.make }
      let(:associated_private_domain_guid) { associated_private_domain.guid }
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make }
      let(:private_domain_guid) { private_domain.guid }

      standard_model_list :private_domain, VCAP::CloudController::PrivateDomainsController, outer_model: :organization
      nested_model_associate :private_domain, :organization
      nested_model_remove :private_domain, :organization
    end

    describe 'Users' do
      before do
        organization.add_user(associated_user)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_user.guid => 'user@example.com' })
      end

      let!(:associated_user) { VCAP::CloudController::User.make }
      let(:associated_user_guid) { associated_user.guid }
      let(:user) { VCAP::CloudController::User.make }
      let(:user_guid) { user.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization
      nested_model_associate :user, :organization
      nested_model_remove :user, :organization
    end

    describe 'Managers' do
      before do
        organization.add_manager(associated_manager)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_manager.guid => 'manager@example.com' })
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

    describe 'Billing Managers' do
      before do
        organization.add_billing_manager(associated_billing_manager)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_billing_manager.guid => 'billing_manager@example.com' })
      end

      let!(:associated_billing_manager) { VCAP::CloudController::User.make }
      let(:associated_billing_manager_guid) { associated_billing_manager.guid }
      let(:billing_manager) { VCAP::CloudController::User.make }
      let(:billing_manager_guid) { billing_manager.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :billing_managers
      nested_model_associate :billing_manager, :organization
      nested_model_remove :billing_manager, :organization
    end

    describe 'Auditors' do
      before do
        organization.add_auditor(associated_auditor)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_auditor.guid => 'auditor@example.com' })
      end

      let!(:associated_auditor) { VCAP::CloudController::User.make }
      let(:associated_auditor_guid) { associated_auditor.guid }
      let(:auditor) { VCAP::CloudController::User.make }
      let(:auditor_guid) { auditor.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :organization, path: :auditors
      nested_model_associate :auditor, :organization
      nested_model_remove :auditor, :organization
    end

    describe 'Services' do
      before do
        some_service = VCAP::CloudController::Service.make(active: true)
        VCAP::CloudController::ServicePlan.make(service: some_service, public: false)
        space = VCAP::CloudController::Space.make(organization: organization)
        VCAP::CloudController::ServicePlanVisibility.make(service_plan: some_service.service_plans.first, organization: space.organization)
      end

      standard_model_list :service, VCAP::CloudController::ServicesController, outer_model: :organization, path: :service
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
  end
end
