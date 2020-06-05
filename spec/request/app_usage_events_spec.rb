require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'App Usage Events' do
  let(:user) { make_user }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  describe 'GET /v3/app_usage_events/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/app_usage_events/#{usage_event.guid}", nil, user_headers } }

    let(:usage_event) { VCAP::CloudController::AppUsageEvent.make }

    let(:usage_event_json) { build_usage_event_json(usage_event) }

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 404,
        response_object: []
      )
      h['admin'] = {
        code: 200,
        response_object: usage_event_json
      }
      h['admin_read_only'] = {
        code: 200,
        response_object: usage_event_json
      }
      h['global_auditor'] = {
        code: 200,
        response_object: usage_event_json
      }
      h.freeze
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when the usage event does not exist' do
      it 'returns a 404' do
        get '/v3/app_usage_events/does-not-exist', nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('App usage event not found')
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/app_usage_events/#{usage_event.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'GET /v3/app_usage_events' do
    let(:api_call) { lambda { |user_headers| get '/v3/app_usage_events', nil, user_headers } }

    let!(:app_usage_event) { VCAP::CloudController::AppUsageEvent.make(created_at: Time.now - 5.minutes) }
    let!(:app_usage_event_2) { VCAP::CloudController::AppUsageEvent.make(created_at: Time.now - 5.minutes) }

    let(:app_usage_event_json) { build_usage_event_json(app_usage_event) }
    let(:app_usage_event_2_json) { build_usage_event_json(app_usage_event_2) }

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 200,
        response_objects: []
      )
      h['admin'] = {
        code: 200,
        response_objects: [app_usage_event_json, app_usage_event_2_json]
      }
      h['admin_read_only'] = {
        code: 200,
        response_objects: [app_usage_event_json, app_usage_event_2_json]
      }
      h['global_auditor'] = {
        code: 200,
        response_objects: [app_usage_event_json, app_usage_event_2_json]
      }
      h.freeze
    end

    it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/app_usage_events', nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when using the guids filter' do
      it 'returns the usage event matching the requested guid' do
        get "/v3/app_usage_events?guids=#{app_usage_event.guid}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['resources'][0]).to match_json_response(app_usage_event_json)
      end
    end

    context 'when using an invalid filter' do
      it 'returns a 422 with a helpful message' do
        get '/v3/app_usage_events?garbage=true', nil, admin_headers
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Unknown query parameter(s): 'garbage'.")
      end
    end
  end

  def build_usage_event_json(app_usage_event)
    {
      'guid' => app_usage_event.guid,
      'created_at' => iso8601,
      'updated_at' => iso8601,
      'data' => {
        'state' => {
          'current' => app_usage_event.state,
          'previous' => nil
        },
        'app' => {
          'guid' => app_usage_event.parent_app_guid,
          'name' => app_usage_event.parent_app_name
        },
        'process' => {
          'guid' => app_usage_event.app_guid,
          'type' => app_usage_event.process_type,
        },
        'space' => {
          'guid' => app_usage_event.space_guid,
          'name' => app_usage_event.space_name
        },
        'organization' => {
          'guid' => app_usage_event.org_guid
        },
        'buildpack' => {
          'guid' => app_usage_event.buildpack_guid,
          'name' => app_usage_event.buildpack_name
        },
        'task' => {
          'guid' => nil,
          'name' => nil
        },
        'memory_in_mb_per_instance' => {
          'current' => app_usage_event.memory_in_mb_per_instance,
          'previous' => nil
        },
        'instance_count' => {
          'current' => app_usage_event.instance_count,
          'previous' => nil
        }
      }
    }
  end
end
