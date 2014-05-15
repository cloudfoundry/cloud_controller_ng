require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:admin_buildpack) { VCAP::CloudController::Buildpack.make }
  let(:guid) { VCAP::CloudController::App.first.guid }
  let!(:apps) { 3.times { VCAP::CloudController::AppFactory.make } }

  authenticated_request

  describe "Standard app endpoints" do
    field :guid, "The guid of the app.", required: false
    field :name, "The name of the app.", required: true, example_values: ["my_super_app"]
    field :memory, "The amount of memory each instance should have. In megabytes.", required: true, example_values: [1_024, 512]
    field :instances, "The number of instances of the app to run. To ensure optimal availability, ensure there are at least 2 instances.", required: true, example_values: [2, 6, 10]
    field :disk_quota, "The maximum amount of disk available to an instance of an app. In megabytes.", required: true, example_values: [1_204, 2_048]
    field :space_guid, "The guid of the associated space.", required: true, example_values: [Sham.guid]

    field :stack_guid, "The guid of the associated stack.", required: false, default: "Uses the default system stack."
    field :state, "The current desired state of the app. One of STOPPED or STARTED.", required: false, default: "STOPPED", valid_values: %w[STOPPED STARTED] # nice to validate this eventually..
    field :command, "The command to start an app after it is staged (e.g. 'rails s -p $PORT' or 'java com.org.Server $PORT').", required: false
    field :buildpack, "Buildpack to build the app. 3 options: a) Blank means autodetection; b) A Git Url pointing to a buildpack; c) Name of an installed buildpack.",
          required: false, default: "", example_values: ["", "https://github.com/virtualstaticvoid/heroku-buildpack-r.git", "an_example_installed_buildpack"]
    field :health_check_timeout, "Timeout for health checking of an staged app when starting up", required: false
    field :environment_json, "Key/value pairs of all the environment variables to run in your app. Does not include any system or service variables.", required: false

    field :detected_buildpack, "The autodetected buildpack that staged the app.", required: false, readonly: true
    field :space_url, "The url of the associated space.", required: false, readonly: true
    field :stack_url, "The url of the associated stack.", required: false, readonly: true
    field :service_bindings_url, "The url of all the associated service bindings.", required: false, readonly: true
    field :routes_url, "The url of all the associated routes.", required: false, readonly: true
    field :events_url, "The url of all the associated events.", required: false, readonly: true

    field :production, "Deprecated.", required: false, deprecated: true, default: true, valid_values: [true, false]
    field :console, "Open the console port for the app (at $CONSOLE_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]
    field :debug, "Open the debug port for the app (at $DEBUG_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]
    field :package_state, "The current desired state of the package. One of PENDING, STAGED or FAILED.", required: false, readonly: true, valid_values: %w[PENDING STAGED FAILED]
    field :system_env_json, "environment_json for system variables, contains vcap_services by default, a hash containing key/value pairs of the names and information of the services associated with your app.", required: false, readonly: true

    standard_model_list :app, VCAP::CloudController::AppsController
    standard_model_get :app
    standard_model_delete_without_async :app

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(:type => "audit.app.delete-request", :actee => guid)
      audited_event event
    end

    put "/v2/apps/:guid" do
      let(:buildpack) { "http://github.com/a-buildpack" }

      example "Set a custom buildpack URL for an Application" do

        explanation <<-EOD
        PUT with the buildpack attribute set to the URL of a git repository to set a custom buildpack.
        EOD

        client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(buildpack: buildpack), headers
        status.should == 201
        standard_entity_response parsed_response, :app, :buildpack => buildpack

        audited_event VCAP::CloudController::Event.find(:type => "audit.app.update", :actee => guid)
      end
    end

    put "/v2/apps/:guid" do
      let(:buildpack) { admin_buildpack.name }

      example "Set a admin buildpack for an Application (by sending the name of an existing buildpack)" do

        explanation <<-EOD
        When the buildpack name matches the name of an admin buildpack, an admin buildpack is used rather
        than a custom buildpack. The 'buildpack' column returns the name of the configured admin buildpack
        EOD

        client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(buildpack: buildpack), headers
        status.should == 201
        standard_entity_response parsed_response, :app, :buildpack => admin_buildpack.name

        audited_event VCAP::CloudController::Event.find(:type => "audit.app.update", :actee => guid)
      end
    end

    post "/v2/apps/" do
      example "Creating an app" do
        space_guid = VCAP::CloudController::Space.make.guid
        client.post "/v2/apps", Yajl::Encoder.encode(required_fields.merge(space_guid: space_guid)), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app

        app_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(:type => "audit.app.create", :actee => app_guid)
      end
    end
  end

  get "/v2/apps/:guid/env" do
    field :guid, "The guid of the app.", required: true


    let(:app_obj) { VCAP::CloudController::AppFactory.make(detected_buildpack: "buildpack-name", environment_json: {env_var: "env_val"})}

    example "Get the env for an Application" do
      explanation <<-EOD
        Get the environment variables for an Application using the guid
      EOD

      client.get "/v2/apps/#{app_obj.guid}/env", {}, headers
      expect(status).to eq(200)
      expect(parsed_response).to have_key('system_env_json')
      expect(parsed_response).to have_key('environment_json')
    end
  end
end
