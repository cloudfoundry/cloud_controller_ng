require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Spaces', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:space) { VCAP::CloudController::Space.make }
  let(:guid) { space.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the Space'
  end

  describe 'Standard endpoints' do
    shared_context 'createable_fields' do |opts|
      field :name, 'The name of the space', required: opts[:required], example_values: %w(development demo production)
      field :organization_guid, 'The guid of the associated organization', required: opts[:required], example_values: [Sham.guid]
      field :developer_guids, 'The list of the associated developers'
      field :manager_guids, 'The list of the associated managers'
      field :auditor_guids, 'The list of the associated auditors'
      field :domain_guids, 'The list of the associated domains'
      field :security_group_guids, 'The list of the associated security groups'
      field :space_quota_definition_guid, 'The guid of the associated space quota definition'
      field :allow_ssh, 'Whether or not Space Developers can enable ssh on apps in the space'
    end

    shared_context 'updatable_fields' do |opts|
      field :name, 'The name of the space', example_values: %w(development demo production)
      field :organization_guid, 'The guid of the associated organization', example_values: [Sham.guid]
      field :developer_guids, 'The list of the associated developers'
      field :manager_guids, 'The list of the associated managers'
      field :auditor_guids, 'The list of the associated auditors'
      field :domain_guids, 'The list of the associated domains'
      field :security_group_guids, 'The list of the associated security groups'
      field :allow_ssh, 'Whether or not Space Developers can enable ssh on apps in the space'
    end

    standard_model_list :space, VCAP::CloudController::SpacesController
    standard_model_get :space, nested_associations: [:organization]
    standard_model_delete :space do
      parameter :recursive, 'Will delete all apps, services, and routes associated with the space', valid_values: [true, false]
    end

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(type: 'audit.space.delete-request', actee: guid)
      audited_event event
    end

    post '/v2/spaces/' do
      include_context 'createable_fields', required: true
      example 'Creating a Space' do
        organization_guid = VCAP::CloudController::Organization.make.guid
        client.post '/v2/spaces', MultiJson.dump(required_fields.merge(organization_guid: organization_guid), pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :space

        space_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.space.create', actee: space_guid)
      end
    end

    put '/v2/spaces/:guid' do
      include_context 'updatable_fields', required: false
      include_context 'guid_parameter'

      let(:new_name) { 'New Space Name' }

      example 'Update a Space' do
        client.put "/v2/spaces/#{guid}",
          MultiJson.dump({ name: new_name }, pretty: true),
          headers

        expect(status).to eq 201
        standard_entity_response parsed_response, :space, name: new_name

        audited_event VCAP::CloudController::Event.find(type: 'audit.space.update', actee: guid)
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'

    describe 'Routes' do
      before do
        domain = VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization)
        VCAP::CloudController::Route.make(domain: domain, space: space)
      end

      standard_model_list :route, VCAP::CloudController::RoutesController, outer_model: :space
    end

    describe 'Developers' do
      before do
        space.organization.add_user(associated_developer)
        space.organization.add_user(developer)
        space.add_developer(associated_developer)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_developer.guid => 'developer@example.com' })
      end

      let!(:associated_developer) { VCAP::CloudController::User.make }
      let(:associated_developer_guid) { associated_developer.guid }
      let(:developer) { VCAP::CloudController::User.make }
      let(:developer_guid) { developer.guid }

      parameter :developer_guid, 'The guid of the developer'

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :developers
      nested_model_associate :developer, :space
      nested_model_remove :developer, :space

      put 'v2/spaces/:guid/developers' do
        example 'Associate Developer with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(developer.guid)

          client.put "v2/spaces/#{space.guid}/developers", MultiJson.dump({ username: 'user@example.com' }, pretty: true), headers
          expect(status).to eq(201)

          standard_entity_response parsed_response, :space
        end
      end

      delete 'v2/spaces/:guid/developers' do
        example 'Disassociate Developer with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(associated_developer.guid)

          client.delete "v2/spaces/#{space.guid}/developers", MultiJson.dump({ username: 'developer@example.com' }, pretty: true), headers
          expect(status).to eq(200)

          standard_entity_response parsed_response, :space
        end
      end
    end

    describe 'Managers' do
      before do
        space.organization.add_user(associated_manager)
        space.organization.add_user(manager)
        space.add_manager(associated_manager)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_manager.guid => 'manager@example.com' })
      end

      let!(:associated_manager) { VCAP::CloudController::User.make }
      let(:associated_manager_guid) { associated_manager.guid }
      let(:manager) { VCAP::CloudController::User.make }
      let(:manager_guid) { manager.guid }

      parameter :manager_guid, 'The guid of the manager'

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :managers
      nested_model_associate :manager, :space
      nested_model_remove :manager, :space

      put 'v2/spaces/:guid/managers' do
        example 'Associate Manager with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(manager.guid)

          client.put "v2/spaces/#{space.guid}/managers", MultiJson.dump({ username: 'user@example.com' }, pretty: true), headers
          expect(status).to eq(201)

          standard_entity_response parsed_response, :space
        end
      end

      delete 'v2/spaces/:guid/managers' do
        example 'Disassociate Manager with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(associated_manager.guid)

          client.delete "v2/spaces/#{space.guid}/managers", MultiJson.dump({ username: 'manager@example.com' }, pretty: true), headers
          expect(status).to eq(200)

          standard_entity_response parsed_response, :space
        end
      end
    end

    describe 'Auditors' do
      before do
        space.organization.add_user(associated_auditor)
        space.organization.add_user(auditor)
        space.add_auditor(associated_auditor)
        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ associated_auditor.guid => 'auditor@example.com' })
      end

      let!(:associated_auditor) { VCAP::CloudController::User.make }
      let(:associated_auditor_guid) { associated_auditor.guid }
      let(:auditor) { VCAP::CloudController::User.make }
      let(:auditor_guid) { auditor.guid }

      parameter :auditor_guid, 'The guid of the auditor'

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :auditors
      nested_model_associate :auditor, :space
      nested_model_remove :auditor, :space

      put 'v2/spaces/:guid/auditors' do
        example 'Associate Auditor with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(auditor.guid)

          client.put "v2/spaces/#{space.guid}/auditors", MultiJson.dump({ username: 'user@example.com' }, pretty: true), headers
          expect(status).to eq(201)

          standard_entity_response parsed_response, :space
        end
      end

      delete 'v2/spaces/:guid/auditors' do
        example 'Disassociate Auditor with the Space by Username (experimental)' do
          uaa_client = double(:uaa_client)
          allow(CloudController::DependencyLocator.instance).to receive(:username_lookup_uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:id_for_username).and_return(associated_auditor.guid)

          client.delete "v2/spaces/#{space.guid}/auditors", MultiJson.dump({ username: 'auditor@example.com' }, pretty: true), headers
          expect(status).to eq(200)

          standard_entity_response parsed_response, :space
        end
      end
    end

    describe 'User Roles' do
      let(:everything_user) { VCAP::CloudController::User.make }

      before do
        space.organization.add_user(everything_user)
        space.add_manager(everything_user)
        space.add_auditor(everything_user)
        space.add_developer(everything_user)

        allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).and_return({ everything_user.guid => 'everything@example.com' })
      end

      get '/v2/spaces/:guid/user_roles' do
        pagination_parameters

        example 'Retrieving the roles of all Users in the Space' do
          client.get "/v2/spaces/#{guid}/user_roles?results-per-page=1&page=1", {}, headers

          expect(status).to eq(200)
          expect(parsed_response['resources'].length).to eq(1)
          expect(parsed_response['resources'][0]['entity']['space_roles']).
            to include('space_developer', 'space_manager', 'space_auditor')
        end
      end
    end

    describe 'Apps' do
      before do
        VCAP::CloudController::AppFactory.make(space: space)
      end

      standard_model_list :app, VCAP::CloudController::AppsController, outer_model: :space
    end

    describe 'Domains' do
      standard_model_list :shared_domain, VCAP::CloudController::DomainsController, outer_model: :space, path: :domains
    end

    describe 'Service Instances' do
      before do
        VCAP::CloudController::ManagedServiceInstance.make(space: space)
      end

      request_parameter :return_user_provided_service_instances, "When 'true', include user provided service instances."

      standard_model_list :managed_service_instance, VCAP::CloudController::ServiceInstancesController, outer_model: :space, path: :service_instances
    end

    describe 'Services' do
      before do
        some_service = VCAP::CloudController::Service.make(active: true)
        VCAP::CloudController::ServicePlan.make(service: some_service, public: false)
        VCAP::CloudController::ServicePlanVisibility.make(service_plan: some_service.service_plans.first, organization: space.organization)
      end

      standard_model_list :service, VCAP::CloudController::ServicesController, outer_model: :space, path: :service
    end

    describe 'Events' do
      before do
        user = VCAP::CloudController::User.make
        space_event_repository = VCAP::CloudController::Repositories::Runtime::SpaceEventRepository.new
        space_event_repository.record_space_update(space, user, 'user@example.com', { 'name' => 'new_name' })
      end

      standard_model_list :event, VCAP::CloudController::EventsController, outer_model: :space
    end

    describe 'Security Groups' do
      let!(:associated_security_group) { VCAP::CloudController::SecurityGroup.make(space_guids: [space.guid]) }
      let(:associated_security_group_guid) { associated_security_group.guid }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }
      let(:security_group_guid) { security_group.guid }

      parameter :security_group_guid, 'The guid of the security group'

      standard_model_list :security_group, VCAP::CloudController::SecurityGroupsController, outer_model: :space
      nested_model_associate :security_group, :space
      nested_model_remove :security_group, :space
    end
  end
end
