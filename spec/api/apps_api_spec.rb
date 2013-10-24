require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before { 3.times { VCAP::CloudController::AppFactory.make } }

  let(:admin_buildpack) { VCAP::CloudController::Buildpack.make }

  let(:guid) { VCAP::CloudController::App.first.guid }

  standard_parameters

  field :name, "The name of the app.", required: true
  field :memory, "The amount of memory each instance should have. In bytes.", required: true
  field :instances, "The number of instances of the app to run. To ensure optimal availability, ensure there are at least 2 instances.", required: true
  field :disk_quota, "The maximum amount of disk available to an instance of an app. In megabytes.", required: true
  field :space_guid, "The guid of the associated space.", required: true

  field :stack_guid, "The guid of the associated stack.", required: false, default: "Uses the default system stack."
  field :state, "The current desired state of the app. One of STOPPED or STARTED.", required: false, default: "STOPPED", valid_values: %w[STOPPED STARTED] # nice to validate this eventually..
  field :command, "The command to start an app after it is staged (e.g. 'rails s -p $PORT' or 'java com.org.Server $PORT').", required: false
  field :buildpack, "Buildpack to build the app. 3 options: a) Blank means autodetection; b) A Git Url pointing to a buildpack; c) Name of an installed buildpack.", required: false, default: "", example_values: ["", "https://github.com/virtualstaticvoid/heroku-buildpack-r.git", "an_example_installed_buildpack"]
  field :environment_json, "Key/value pairs of all the environment variables to run in your app. Does not include any system or service variables.", required: false

  field :detected_buildpack, "The autodetected buildpack that was run.", required: false, readonly: true
  field :space_url, "The url of the associated space.", required: false, readonly: true
  field :stack_url, "The url of the associated stack.", required: false, readonly: true
  field :service_bindings_url, "The url of all the associated service bindings.", required: false, readonly: true
  field :routes_url, "The url of all the associated routes.", required: false, readonly: true
  field :events_url, "The url of all the associated events.", required: false, readonly: true

  field :production, "Deprecated.", required: false, deprecated: true, default: true, valid_values: [true, false]
  field :console, "Open the console port for the app (at $CONSOLE_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]
  field :debug, "Open the debug port for the app (at $DEBUG_PORT).", required: false, deprecated: true, default: false, valid_values: [true, false]

  standard_model_list :app
  standard_model_get :app
  standard_model_delete :app

  def after_standard_model_delete(guid)
    event = VCAP::CloudController::Event.find(:type => "audit.app.delete", :actee => guid)
    audited_event event
  end

  put "/v2/apps/:guid" do
    let(:buildpack) { "http://github.com/a-buildpack" }

    example "Set a custom buildpack URL for an Application" do

      explanation <<-EOD
        PUT with the buildpack attribute set to the URL of a git repository to set a custom buildpack.
      EOD

      client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(params), headers
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

      client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(params), headers
      status.should == 201
      standard_entity_response parsed_response, :app, :buildpack => admin_buildpack.name

      audited_event VCAP::CloudController::Event.find(:type => "audit.app.update", :actee => guid)
    end
  end

  post "/v2/apps/" do
    let(:space_guid) { VCAP::CloudController::Space.make.guid.to_s }

    example "Creating an app" do
      client.post "/v2/apps", Yajl::Encoder.encode(name: "my-app", space_guid: space_guid), headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :app

      app_guid = parsed_response['metadata']['guid']
      audited_event VCAP::CloudController::Event.find(:type => "audit.app.create", :actee => app_guid)
    end
  end
end
