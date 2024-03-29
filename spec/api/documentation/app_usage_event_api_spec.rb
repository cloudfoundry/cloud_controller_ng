require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'App Usage Events', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }

  authenticated_request
  let(:guid) { VCAP::CloudController::AppUsageEvent.first.guid }
  let!(:event1) { VCAP::CloudController::AppUsageEvent.make }
  let!(:event2) { VCAP::CloudController::AppUsageEvent.make }
  let!(:event3) { VCAP::CloudController::AppUsageEvent.make }
  describe 'Standard endpoints' do
    standard_model_get :app_usage_event

    get '/v2/app_usage_events' do
      field :app_guid, 'The GUID of the app.', required: false, readonly: true
      field :app_name, 'The name of the app.', required: false, readonly: true
      field :buildpack_guid, 'The GUID of the buildpack used to stage the app.', required: false, readonly: true
      field :buildpack_name,
            'The name of the buildpack or the URL of the custom buildpack used to stage the app.',
            required: false,
            readonly: true,
            example_values: %w[https://example.com/buildpack.git admin_buildpack]
      field :created_at,
            'The timestamp when the event is recorded. It is possible that later events may have earlier created_at values.',
            required: false,
            readonly: true
      field :guid, 'The guid of the event.', required: false
      field :instance_count, 'The number of instance of an application', required: false, readonly: true
      field :memory_in_mb_per_instance, 'Memory usage per app instance.', required: false, readonly: true, example_values: %w[128 256 512]
      field :org_guid, 'The GUID of the organization.', required: false, readonly: true
      field :package_state, 'The state of the package.', required: false, readonly: true, valid_values: ['PENDING', 'STAGED', ' FAILED']
      field :parent_app_guid, 'The GUID for a parent v3 application if one exists', required: false, readonly: true, experimental: true
      field :parent_app_name, 'The name for a parent v3 application if one exists', required: false, readonly: true, experimental: true
      field :previous_instance_count, 'The number of instance of an application previously', required: false, readonly: true
      field :previous_memory_in_mb_per_instance, 'Previous memory usage per app instance.', required: false, readonly: true, example_values: %w[128 256 512]
      field :previous_package_state, 'The previous state of the package.', required: false, readonly: true, valid_values: ['PENDING', 'STAGED', ' FAILED']
      field :previous_state,
            "The previous desired state of the app or 'BUILDPACK_SET' when buildpack info has been set.",
            required: false,
            readonly: true,
            valid_values: %w[STARTED STOPPED BUILDPACK_SET TASK_STARTED TASK_STOPPED]
      field :process_type, 'The process_type for applications.', required: false, readonly: true, experimental: true
      field :space_guid, 'The GUID of the space.', required: false, readonly: true
      field :space_name, 'The name of the space.', required: false, readonly: true
      field :state,
            "The desired state of the app or 'BUILDPACK_SET' when buildpack info has been set.",
            required: false,
            readonly: true,
            valid_values: %w[STARTED STOPPED BUILDPACK_SET TASK_STARTED TASK_STOPPED]
      field :task_guid, 'The GUID of the task if one exists.', required: false, readonly: true, experimental: true
      field :task_name, 'The NAME of the task if one exists.', required: false, readonly: true, experimental: true

      standard_list_parameters VCAP::CloudController::AppUsageEventsController

      request_parameter :after_guid, 'Restrict results to App Usage Events after the one with the given guid'

      example 'List all App Usage Events' do
        explanation <<-DOC
        Events are sorted by internal database IDs. This order may differ from created_at.

        Events close to the current time should not be processed because other events may still have open
        transactions that will change their order in the results.
        DOC

        client.get "/v2/app_usage_events?results-per-page=1&after_guid=#{event1.guid}", {}, headers
        expect(status).to eq(200)
        standard_entity_response parsed_response['resources'][0], :app_usage_event,
                                 expected_values: {
                                   state: event2.state,
                                   package_state: event2.package_state,
                                   instance_count: event2.instance_count,
                                   memory_in_mb_per_instance: event2.memory_in_mb_per_instance,
                                   app_guid: event2.app_guid,
                                   app_name: event2.app_name,
                                   space_guid: event2.space_guid,
                                   space_name: event2.space_name,
                                   org_guid: event2.org_guid,
                                   parent_app_guid: nil,
                                   parent_app_name: nil,
                                   process_type: 'web',
                                   task_guid: nil,
                                   task_name: nil
                                 }
      end
    end
  end

  post '/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps', isolation: :truncation do
    example 'Purge and reseed App Usage Events' do
      explanation <<-DOC
        Destroys all existing events. Populates new usage events, one for each started app.
        All populated events will have a created_at value of current time.

        There is the potential race condition if apps are currently being started, stopped, or scaled.

        The seeded usage events will have the same guid as the app.
      DOC

      client.post '/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps', {}, headers
      expect(status).to eq(204)
    end
  end
end
