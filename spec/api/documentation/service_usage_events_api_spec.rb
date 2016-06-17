require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Service Usage Events', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  authenticated_request
  let(:guid) { VCAP::CloudController::ServiceUsageEvent.first.guid }
  let!(:event1) { VCAP::CloudController::ServiceUsageEvent.make }
  let!(:event2) { VCAP::CloudController::ServiceUsageEvent.make }
  let!(:event3) { VCAP::CloudController::ServiceUsageEvent.make }

  standard_model_get :service_usage_event

  get '/v2/service_usage_events' do
    field :guid, 'The guid of the event.', required: false
    field :state, 'The desired state of the service.', required: false, readonly: true, valid_values: ['CREATED', 'DELETED', 'UPDATED']
    field :org_guid, 'The GUID of the organization.', required: false, readonly: true
    field :space_guid, 'The GUID of the space.', required: false, readonly: true
    field :space_name, 'The name of the space.', required: false, readonly: true
    field :service_instance_guid, 'The GUID of the service instance.', required: false, readonly: true
    field :service_instance_name, 'The name of the service instance.', required: false, readonly: true
    field :service_instance_type, 'The type of the service instance.', required: false, readonly: true, valid_values: ['managed_service_instance', 'user_provided_service_instance']
    field :service_plan_guid, 'The GUID for the service plan.', required: false, readonly: true
    field :service_plan_name, 'The name for the service plan.', required: false, readonly: true
    field :service_guid, 'The GUID of the service.', required: false, readonly: true
    field :created_at, 'The timestamp of the event creation.', required: false, readonly: true
    field :service_label, 'The name of the service.', required: false, readonly: true

    standard_list_parameters VCAP::CloudController::ServiceUsageEventsController

    request_parameter :after_guid, 'Restrict results to Service Usage Events after the one with the given guid'

    example 'List Service Usage Events' do
      explanation <<-DOC
        Events are sorted by internal database IDs. This order may differ from created_at.

        Events close to the current time should not be processed because other events may still have open
        transactions that will change their order in the results.
      DOC

      client.get "/v2/service_usage_events?results-per-page=1&after_guid=#{event1.guid}", {}, headers
      expect(status).to eq(200)
      standard_list_response parsed_response, :service_usage_event
    end
  end

  post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances', isolation: :truncation do
    example 'Purge and reseed Service Usage Events' do
      explanation <<-DOC
        Destroys all existing events. Populates new usage events, one for each existing service instance.
        All populated events will have a created_at value of current time.

        There is the potential race condition if service instances are currently being created or deleted.

        The seeded usage events will have the same guid as the service instance.
      DOC

      client.post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances', {}, headers
      expect(status).to eq(204)
    end
  end
end
