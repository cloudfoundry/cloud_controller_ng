require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "App Usage Events (experimental)", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request
  before do
    VCAP::CloudController::AppUsageEvent.make
  end

  field :guid, "The guid of the event.", required: false
  field :state, "The state of the app.", required: false, readonly: true, valid_values: ["STARTED", "STOPPED"]
  field :instance_count, "How many instance of the app.", required: false, readonly: true
  field :memory_in_mb_per_instance, "How much memory per app instance.", required: false, readonly: true, example_values: %w[128 256 512]
  field :app_guid, "The GUID of the app.", required: false, readonly: true
  field :app_name, "The name of the app.", required: false, readonly: true
  field :org_guid, "The GUID of the organization.", required: false, readonly: true
  field :space_guid, "The GUID of the space.", required: false, readonly: true
  field :space_name, "The name of the space.", required: false, readonly: true
  field :created_at, "The timestamp when the event is recorded. It is possible that later events may have earlier created_at values.", required: false, readonly: true

  standard_model_list(:app_usage_event, VCAP::CloudController::AppUsageEventsController)
end
