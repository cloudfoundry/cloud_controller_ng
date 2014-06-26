require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Events", :type => :api do
  DOCUMENTED_EVENT_TYPES = %w[app.crash audit.app.update audit.app.create audit.app.delete-request audit.space.create audit.space.update audit.space.delete-request]
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do
      VCAP::CloudController::Event.make
    end
  end

  let(:guid) { VCAP::CloudController::Event.first.guid }

  field :guid, "The guid of the event.", required: false
  field :type, "The type of the event.", required: false, readonly: true, valid_values: DOCUMENTED_EVENT_TYPES, example_values: %w[app.crash audit.app.update]
  field :actor, "The GUID of the actor.", required: false, readonly: true
  field :actor_type, "The actor type.", required: false, readonly: true, example_values: %w[user app]
  field :actor_name, "The name of the actor.", required: false, readonly: true
  field :actee, "The GUID of the actee.", required: false, readonly: true
  field :actee_type, "The actee type.", required: false, readonly: true, example_values: %w[space app]
  field :actee_name, "The name of the actee.", required: false, readonly: true
  field :timestamp, "The event creation time.", required: false, readonly: true
  field :metadata, "The additional information about event.", required: false, readonly: true, default: {}
  field :space_guid, "The guid of the associated space.", required: false, readonly: true
  field :organization_guid, "The guid of the associated organization.", required: false, readonly: true

  standard_model_list(:event, VCAP::CloudController::EventsController)
  standard_model_get(:event)

  get "/v2/events" do
    standard_list_parameters VCAP::CloudController::EventsController

    let(:test_app) { VCAP::CloudController::App.make }
    let(:test_user) { VCAP::CloudController::User.make }
    let(:test_user_email) { "user@email.com" }
    let(:test_space) { VCAP::CloudController::Space.make }
    let(:app_request) do
      {
        "name" => "new",
        "instances" => 1,
        "memory" => 84,
        "state" => "STOPPED",
        "environment_json" => { "super" => "secret" }
      }
    end
    let(:space_request) do
      {
        "name" => "outer space"
      }
    end
    let(:droplet_exited_payload) do
      {
        "instance" => 0,
        "index" => 1,
        "exit_status" => "1",
        "exit_description" => "out of memory",
        "reason" => "crashed"
      }
    end
    let(:expected_app_request) do
      expected_request = app_request
      expected_request["environment_json"] = "PRIVATE DATA HIDDEN"
      expected_request
    end

    let(:app_event_repository) do
      VCAP::CloudController::Repositories::Runtime::AppEventRepository.new
    end

    let(:space_event_repository) do
      VCAP::CloudController::Repositories::Runtime::SpaceEventRepository.new
    end

    example "List App Create Events" do
      app_event_repository.record_app_create(test_app, test_user, test_user_email, app_request)

      client.get "/v2/events?q=type:audit.app.create", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee_type => "app",
                               :actee => test_app.guid,
                               :actee_name => test_app.name,
                               :space_guid => test_app.space.guid,
                               :metadata => { "request" => expected_app_request }

    end

    example "List App Exited Events" do
      app_event_repository.create_app_exit_event(test_app, droplet_exited_payload)

      client.get "/v2/events?q=type:app.crash", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "app",
                               :actor => test_app.guid,
                               :actor_name => test_app.name,
                               :actee_type => "app",
                               :actee => test_app.guid,
                               :actee_name => test_app.name,
                               :space_guid => test_app.space.guid,
                               :metadata => droplet_exited_payload

    end

    example "List App Update Events" do
      app_event_repository.record_app_update(test_app, test_user, test_user_email, app_request)

      client.get "/v2/events?q=type:audit.app.update", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee_type => "app",
                               :actee => test_app.guid,
                               :actee_name => test_app.name,
                               :space_guid => test_app.space.guid,
                               :metadata => {
                                 "request" => expected_app_request,
                               }

    end

    example "List App Delete Events" do
      app_event_repository.record_app_delete_request(test_app, test_user, test_user_email, false)

      client.get "/v2/events?q=type:audit.app.delete-request", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee_type => "app",
                               :actee => test_app.guid,
                               :actee_name => test_app.name,
                               :space_guid => test_app.space.guid,
                               :metadata => { "request" => { "recursive" => false } }
    end

    example "List Space Create Events" do
      space_event_repository.record_space_create(test_space, test_user, test_user_email, space_request)

      client.get "/v2/events?q=type:audit.space.create", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee_type => "space",
                               :actee => test_space.guid,
                               :actee_name => test_space.name,
                               :space_guid => test_space.guid,
                               :metadata => { "request" => space_request }

    end

    example "List Space Update Events" do
      space_event_repository.record_space_update(test_space, test_user, test_user_email, space_request)

      client.get "/v2/events?q=type:audit.space.update", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee => test_space.guid,
                               :actee_type => "space",
                               :actee_name => test_space.name,
                               :space_guid => test_space.guid,
                               :metadata => { "request" => space_request }
    end

    example "List Space Delete Events" do
      space_event_repository.record_space_delete_request(test_space, test_user, test_user_email, true)

      client.get "/v2/events?q=type:audit.space.delete-request", {}, headers
      expect(status).to eq(200)
      standard_entity_response parsed_response["resources"][0], :event,
                               :actor_type => "user",
                               :actor => test_user.guid,
                               :actor_name => test_user_email,
                               :actee_type => "space",
                               :actee => test_space.guid,
                               :actee_name => test_space.name,
                               :space_guid => test_space.guid,
                               :metadata => { "request" => { "recursive" => true } }
    end
  end
end
