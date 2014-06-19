require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', :type => :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make :space => space, :droplet_hash => nil, :package_state => "PENDING" }
  let(:user) { make_developer_for_space(app_obj.space) }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route1)  { VCAP::CloudController::Route.make(:space => space) }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:space => space) }
  let(:service_binding) { VCAP::CloudController::ServiceBinding.make(:app => app_obj, :service_instance => service_instance) }

  authenticated_request

  get "/v2/apps/:guid/summary" do
    field :guid, "The guid of the app for which summary is requested", required: true
    field :name, "The name of the app.", required: false, readonly: true
    field :memory, "The amount of memory each instance should have. In megabytes.", required: false, readonly: true
    field :instances, "The number of instances of the app to run.", required: false, readonly: true
    field :disk_quota, "The maximum amount of disk available to an instance of an app. In megabytes.", required: false, readonly: true
    field :space_guid, "The guid of the associated space.", required: false, readonly: true

    field :stack_guid, "The guid of the associated stack.", required: false, readonly: true, default: "Uses the default system stack."
    field :state, "The current state of the app. One of STOPPED or STARTED.", required: false, readonly: true, default: "STOPPED", valid_values: %w[STOPPED STARTED] # nice to validate this eventually..
    field :command, "The command to start an app after it is staged (e.g. 'rails s -p $PORT' or 'java com.org.Server $PORT').", required: false, readonly: true
    field :buildpack, "Buildpack to build the app. 3 options: a) Blank means autodetection; b) A Git Url pointing to a buildpack; c) Name of an installed buildpack.", required: false, readonly: true
    field :health_check_timeout, "Timeout for health checking of an staged app when starting up", required: false, readonly: true
    field :environment_json, "Key/value pairs of all the environment variables to run in your app. Does not include any system or service variables.", required: false, readonly: true

    field :detected_buildpack, "The autodetected buildpack that staged the app.", required: false, readonly: true
    field :detected_buildpack_guid, "The guid of the autodetected admin buildpack that staged the app.", required: false, readonly: true
    field :production, "Deprecated.", required: false, deprecated: true, default: true, valid_values: [true, false]
    field :console, "Open the console port for the app (at $CONSOLE_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]
    field :debug, "Open the debug port for the app (at $DEBUG_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]
    field :package_state, "The current state of the package. One of PENDING, STAGED or FAILED.", required: false, readonly: true, valid_values: %w[PENDING STAGED FAILED]
  
    field :system_env_json, "environment_json for system variables, contains vcap_services by default, a hash containing key/value pairs of the names and information of the services associated with your app.", required: false, readonly: true
    field :staging_task_id, "Staging task id",required: false, readonly: true
    field :running_instances, "The number of instances of the app that are currently running.", required: false, readonly: true
    field :available_domain, "List of available domains configured for the app", required: false, readonly: true 
    field :routes, "List of routes configured for the app",required: false, readonly: true
    field :version, "Version guid of the app", required: false, readonly: true
    field :services, "List of services that are bound to the app", required: false, readonly: true

    example "Get app summary" do
      app_obj.add_route(route1)
      service_binding.save
      client.get "/v2/apps/#{app_obj.guid}/summary", {},  headers

      expect(status).to eq 200

      expect(parsed_response["guid"]).to eq(app_obj.guid)
      expect(parsed_response["name"]).to eq(app_obj.name)
      expect(parsed_response["memory"]).to eq(app_obj.memory)

      expect(parsed_response["routes"][0]["host"]).to eq(route1.host)
      expect(parsed_response["services"][0]["name"]).to eq(service_instance.name)
    end
  end
end

resource 'Spaces', :type => :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make :space => space, :droplet_hash => nil, :package_state => "PENDING" }
  let(:user) { make_developer_for_space(app_obj.space) }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route1)  { VCAP::CloudController::Route.make(:space => space) }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:space => space) }
  let(:service_binding) { VCAP::CloudController::ServiceBinding.make(:app => app_obj, :service_instance => service_instance) }

  authenticated_request

  get "/v2/spaces/:guid/summary" do
    field :guid, "The guid of the space for which summary is requested", required: true
    field :name, "The name of the space.", required: false, readonly: true
    field :apps, "List of apps that are running in the space", required: false, readonly: true
    field :services, "List of services that are associated with the space", required: false, readonly: true

    example "Get space summary" do
      app_obj.add_route(route1)
      service_binding.save
      client.get "/v2/spaces/#{space.guid}/summary", {} , headers
      
      expect(status).to eq 200
      expect(parsed_response["guid"]).to eq(space.guid)
      expect(parsed_response["name"]).to eq(space.name)

      expect(parsed_response["apps"][0]["name"]).to eq(app_obj.name)
      expect(parsed_response["services"][0]["name"]).to eq(service_instance.name)
    end
  end
end

resource 'Organizations', :type => :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:organization) { VCAP::CloudController::Organization.make }
  let!(:space) { VCAP::CloudController::Space.make(organization: organization) }

  authenticated_request

  get "/v2/organizations/:guid/summary" do
    field :guid, "The guid of the organization for which summary is requested", required: true
    field :name, "The name of the organization.", required: false, readonly: true
    field :spaces, "List of spaces that are in the organization", required: false, readonly: true
    field :status, "Status of the organization", required: false, readonly: true

    example "Get organization summary" do
      client.get "/v2/organizations/#{organization.guid}/summary", {} , headers

      expect(status).to eq 200
      expect(parsed_response["guid"]).to eq(organization.guid)
      expect(parsed_response["name"]).to eq(organization.name)
      expect(parsed_response["spaces"][0]["name"]).to eq(space.name)
    end
  end
end

