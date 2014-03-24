require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "App Usage Events (experimental)", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request
  let(:guid) { VCAP::CloudController::AppUsageEvent.first.guid }
  let!(:event1) { VCAP::CloudController::AppUsageEvent.make }
  let!(:event2) { VCAP::CloudController::AppUsageEvent.make }
  let!(:event3) { VCAP::CloudController::AppUsageEvent.make }

  get "/v2/app_usage_events" do
    field :guid, "The guid of the event.", required: false
    field :state, "The state of the app.", required: false, readonly: true, valid_values: ["STARTED", "STOPPED"]
    field :instance_count, "How many instance of the app.", required: false, readonly: true
    field :memory_in_mb_per_instance, "How much memory per app instance.", required: false, readonly: true, example_values: %w[128 256 512]
    field :app_guid, "The GUID of the app.", required: false, readonly: true
    field :app_name, "The name of the app.", required: false, readonly: true
    field :org_guid, "The GUID of the organization.", required: false, readonly: true
    field :space_guid, "The GUID of the space.", required: false, readonly: true
    field :space_name, "The name of the space.", required: false, readonly: true
    field :buildpack_guid, "The GUID of the buildpack used to stage the app.", required: false, readonly: true
    field :builpack_name, "The name of the buildpack or the URL of the custom buildpack used to stage the app.", required: false, readonly: true, example_values: %w[https://example.com/buildpack.git admin_buildpack]
    field :created_at, "The timestamp when the event is recorded. It is possible that later events may have earlier created_at values.", required: false, readonly: true

    standard_list_parameters VCAP::CloudController::AppUsageEventsController
    standard_model_get :app_usage_event
    request_parameter :after_guid, "Restrict results to App Usage Events after the one with the given guid"

    example "List app usage events" do
      explanation <<-DOC
        Events are sorted by internal database IDs. This order may differ from created_at.

        Events close to the current time should not be processed because other events may still have open
        transactions that will change their order in the results.
      DOC

      client.get "/v2/app_usage_events?results-per-page=1&after_guid=#{event1.guid}", {}, headers
      status.should == 200
      standard_entity_response parsed_response["resources"][0], :app_usage_event,
                               state: event2.state,
                               instance_count: event2.instance_count,
                               memory_in_mb_per_instance: event2.memory_in_mb_per_instance,
                               app_guid: event2.app_guid,
                               app_name: event2.app_name,
                               space_guid: event2.space_guid,
                               space_name: event2.space_name,
                               org_guid: event2.org_guid
    end
  end

  post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps" do
    example "Purge and reseed app usage events" do
      explanation <<-DOC
        Destroys all existing events. Populates new usage events, one for each started app.
        All populated events will have a created_at value of current time.

        There is the potential race condition if apps are currently being started, stopped, or scaled.

        The seeded usage events will have the same guid as the app.
      DOC

      client.post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", {}, headers
      status.should == 204
    end
  end
end
