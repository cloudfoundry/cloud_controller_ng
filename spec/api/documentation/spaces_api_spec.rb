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
    field :app_security_group_guids, "The list of the associated app security groups", required: false

    standard_model_list :space, VCAP::CloudController::SpacesController
    standard_model_get :space, nested_associations: [:organization]
    standard_model_delete :space

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(type: "audit.space.delete-request", actee: guid)
      audited_event event
    end

    post "/v2/spaces/" do
      example "Creating a space" do
        organization_guid = VCAP::CloudController::Organization.make.guid
        client.post "/v2/spaces", Yajl::Encoder.encode(required_fields.merge(organization_guid: organization_guid)), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :space

        space_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: "audit.space.create", actee: space_guid)
      end
    end

    put "/v2/spaces/:guid" do
      let(:new_name) { "New Space Name" }

      example "Update a space" do
        client.put "/v2/spaces/#{guid}", Yajl::Encoder.encode(name: new_name), headers
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
        make_developer_for_space(space)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :developers
    end

    describe "Managers" do
      before do
        make_manager_for_space(space)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :managers
    end

    describe "Auditors" do
      before do
        make_auditor_for_space(space)
      end

      standard_model_list :user, VCAP::CloudController::UsersController, outer_model: :space, path: :auditors
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

    describe "App Security Groups" do
      before do
        VCAP::CloudController::AppSecurityGroup.make(running_default: true)
      end

      standard_model_list :app_security_group, VCAP::CloudController::AppSecurityGroupsController, outer_model: :space
    end
  end
end
