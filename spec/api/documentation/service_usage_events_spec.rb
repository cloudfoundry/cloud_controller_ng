require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Usage Events (experimental)", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request
  let(:guid) { VCAP::CloudController::ServiceUsageEvent.first.guid }
  let!(:event1) { VCAP::CloudController::ServiceUsageEvent.make }
  let!(:event2) { VCAP::CloudController::ServiceUsageEvent.make }
  let!(:event3) { VCAP::CloudController::ServiceUsageEvent.make }

  get "/v2/service_usage_events" do
    field :guid, "The guid of the event.", required: false
    field :state, "The desired state of the service.", required: false, readonly: true, valid_values: ["CREATED"]
    field :org_guid, "The GUID of the organization.", required: false, readonly: true
    field :space_guid, "The GUID of the space.", required: false, readonly: true
    field :space_name, "The name of the space.", required: false, readonly: true
    field :service_instance_guid, "The GUID of the service instance.", required: false, readonly: true
    field :service_instance_name, "The name of the service instance.", required: false, readonly: true
    field :service_instance_type, "The type of the service instance.", required: false, readonly: true, valid_values: ["managed_service_instance", "user_provided_service_instance"]
    field :service_plan_guid, "The GUID of the service plan.", required: false, readonly: true
    field :service_plan_name, "The name of the service plan.", required: false, readonly: true
    field :service_guid, "The GUID of the service.", required: false, readonly: true
    field :service_label, "The label of the service.", required: false, readonly: true
    field :created_at, "The timestamp when the event is recorded. It is possible that later events may have earlier created_at values.", required: false, readonly: true

    standard_list_parameters VCAP::CloudController::ServiceUsageEventsController
    standard_model_get :service_usage_event
    request_parameter :after_guid, "Restrict results to Service Usage Events after the one with the given guid"

    example "List service usage events" do
      explanation <<-DOC
        Events are sorted by internal database IDs. This order may differ from created_at.

        Events close to the current time should not be processed because other events may still have open
        transactions that will change their order in the results.
      DOC

      client.get "/v2/service_usage_events?results-per-page=1&after_guid=#{event1.guid}", {}, headers
      status.should == 200
      standard_entity_response parsed_response["resources"][0], :service_usage_event,
                               state: event2.state,
                               org_guid: event2.org_guid,
                               space_guid: event2.space_guid,
                               space_name: event2.space_name,
                               service_instance_guid: event2.service_instance_guid,
                               service_instance_name: event2.service_instance_name,
                               service_instance_type: event2.service_instance_type,
                               service_plan_guid: event2.service_plan_guid,
                               service_plan_name: event2.service_plan_name,
                               service_guid: event2.service_guid,
                               service_label: event2.service_label

    end
  end
end
