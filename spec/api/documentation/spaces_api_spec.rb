require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Spaces", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:space) { VCAP::CloudController::Space.make }
  let(:guid) { space.guid }

  authenticated_request

  describe "Standard endpoints" do
    field :guid, "The guid of the space.", required: false
    field :name, "The name of the space", required: true, example_values: %w(development demo production)
    field :organization_guid, "The guid of the associated organization", required: true, example_values: [Sham.guid]
    field :developer_guids, "The list of the associated developers", required: false
    field :manager_guids, "The list of the associated managers", required: false
    field :auditor_guids, "The list of the associated auditors", required: false
    field :domain_guids, "The list of the associated domains", required: false
    field :security_group_guids, "The list of the associated security groups", required: false

    standard_model_list :space, VCAP::CloudController::SpacesController
    standard_model_get :space, nested_associations: [:organization]
    standard_model_delete :space

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(type: "audit.space.delete-request", actee: guid)
      audited_event event
    end

    post "/v2/spaces/" do
      example "Creating a Space" do
        organization_guid = VCAP::CloudController::Organization.make.guid
        client.post "/v2/spaces", MultiJson.dump(required_fields.merge(organization_guid: organization_guid)), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :space

        space_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: "audit.space.create", actee: space_guid)
      end
    end

    put "/v2/spaces/:guid" do
      let(:new_name) { "New Space Name" }

      example "Update a Space" do
        client.put "/v2/spaces/#{guid}", MultiJson.dump(name: new_name), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :space, name: new_name

        audited_event VCAP::CloudController::Event.find(type: "audit.space.update", actee: guid)
      end
    end
  end

  describe "Nested endpoints" do
    field :guid, "The guid of the space.", required: true

    describe "Routes" do
      before do
        domain = VCAP::CloudController::PrivateDomain.make(:owning_organization => space.organization)
        VCAP::CloudController::Route.make(domain: domain, :space => space)
      end

      standard_model_list :route, VCAP::CloudController::RoutesController, outer_model: :space
    end

    describe "Developers" do
      before do
        space.organization.add_user(associated_developer)
        space.organization.add_user(developer)
        space.add_developer(associated_developer)
      end

      let!(:associated_developer) { VCAP::CloudController::User.make }
      let(:associated_developer_guid) { associated_developer.guid }
      let(:developer) { VCAP::CloudController::User.make }
      let(:developer_guid) { developer.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :developers
      nested_model_associate :developer, :space
      nested_model_remove :developer, :space
    end

    describe "Managers" do
      before do
        space.organization.add_user(associated_manager)
        space.organization.add_user(manager)
        space.add_manager(associated_manager)
      end

      let!(:associated_manager) { VCAP::CloudController::User.make }
      let(:associated_manager_guid) { associated_manager.guid }
      let(:manager) { VCAP::CloudController::User.make }
      let(:manager_guid) { manager.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :managers
      nested_model_associate :manager, :space
      nested_model_remove :manager, :space
    end

    describe "Auditors" do
      before do
        space.organization.add_user(associated_auditor)
        space.organization.add_user(auditor)
        space.add_auditor(associated_auditor)
      end

      let!(:associated_auditor) { VCAP::CloudController::User.make }
      let(:associated_auditor_guid) { associated_auditor.guid }
      let(:auditor) { VCAP::CloudController::User.make }
      let(:auditor_guid) { auditor.guid }

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :auditors
      nested_model_associate :auditor, :space
      nested_model_remove :auditor, :space
    end

    describe "Apps" do
      before do
        VCAP::CloudController::AppFactory.make(space: space)
      end

      standard_model_list :app, VCAP::CloudController::AppsController, outer_model: :space
    end

    describe "Domains" do
      standard_model_list :shared_domain, VCAP::CloudController::DomainsController, outer_model: :space, path: :domains
    end

    describe "Service Instances" do
      before do
        VCAP::CloudController::ManagedServiceInstance.make(space: space)
      end

      standard_model_list :managed_service_instance, VCAP::CloudController::ServiceInstancesController, outer_model: :space, path: :service_instances
    end

    describe "Events" do
      before do
        user = VCAP::CloudController::User.make
        space_event_repository = VCAP::CloudController::Repositories::Runtime::SpaceEventRepository.new
        space_event_repository.record_space_update(space, user, "user@example.com", {"name" => "new_name"})
      end

      standard_model_list :event, VCAP::CloudController::EventsController, outer_model: :space
    end

    describe "Security Groups" do
      let!(:associated_security_group) { VCAP::CloudController::SecurityGroup.make(space_guids: [space.guid]) }
      let(:associated_security_group_guid) { associated_security_group.guid }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }
      let(:security_group_guid) { security_group.guid }

      standard_model_list :security_group, VCAP::CloudController::SecurityGroupsController, outer_model: :space
      nested_model_associate :security_group, :space
      nested_model_remove :security_group, :space
    end
  end
end
